"""
views.py

URL route handlers

Note that any handler params must match the URL route params.
For example the *say_hello* handler, handling the URL route '/hello/<username>',
  must be passed *username* as the argument.

"""
from google.appengine.api import users
from google.appengine.ext import ndb
from google.appengine.runtime.apiproxy_errors import CapabilityDisabledError

from flask import request, render_template, flash, url_for, redirect

from flask_cache import Cache

from application import app
from decorators import login_required, admin_required

from forms import ExampleForm, QuestionForm, QuestionSearchForm

from google.appengine.api import search

from models import ExampleModel, Question

# Flask-Cache (configured to use App Engine Memcache API)
cache = Cache(app)


def home():
    return redirect(url_for('list_examples'))


def say_hello(username):
    """Contrived example to demonstrate Flask's url routing capabilities"""
    return 'Hello %s' % username


@login_required
def list_examples():
    """List all examples"""
    examples = ExampleModel.query()
    form = ExampleForm()
    if form.validate_on_submit():
        example = ExampleModel(
            example_name=form.example_name.data,
            example_description=form.example_description.data,
            added_by=users.get_current_user()
        )
        try:
            example.put()
            example_id = example.key.id()
            flash(u'Example %s successfully saved.' % example_id, 'success')
            return redirect(url_for('list_examples'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('list_examples'))
    return render_template('list_examples.html', examples=examples, form=form)

# No auth required
def search_questions():
    """Basic search API for Questions"""
    # questions = []
    search_form = QuestionSearchForm()
    if not search_form.validate_on_submit():
        return redirect(url_for('list_questions'))

    # Build the search params and redirect
    latitude = search_form.latitude.data
    longitude = search_form.longitude.data
    radius = search_form.distance.data
    return redirect(url_for('list_questions', lat=latitude, lon=longitude, r=radius))


@login_required
def edit_example(example_id):
    example = ExampleModel.get_by_id(example_id)
    form = ExampleForm(obj=example)
    if request.method == "POST":
        if form.validate_on_submit():
            example.example_name = form.data.get('example_name')
            example.example_description = form.data.get('example_description')
            example.put()

            flash(u'Example %s successfully saved.' % example_id, 'success')
            return redirect(url_for('list_examples'))
    return render_template('edit_example.html', example=example, form=form)


@login_required
def delete_example(example_id):
    """Delete an example object"""
    example = ExampleModel.get_by_id(example_id)
    if request.method == "POST":
        try:
            example.key.delete()
            flash(u'Example %s successfully deleted.' % example_id, 'success')
            return redirect(url_for('list_examples'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('list_examples'))


@admin_required
def admin_only():
    """This view requires an admin account"""
    return 'Super-seekrit admin page.'


@cache.cached(timeout=60)
def cached_examples():
    """This view should be cached for 60 sec"""
    examples = ExampleModel.query()
    return render_template('list_examples_cached.html', examples=examples)


def warmup():
    """App Engine warmup handler
    See http://code.google.com/appengine/docs/python/config/appconfig.html#Warming_Requests

    """
    return ''


def list_questions():
    """Lists all questions posted on the site"""
    questions = Question.all()
    form = QuestionForm()
    search_form = QuestionSearchForm()

    query_string = request.query_string
    latitude = request.args.get('lat')
    longitude = request.args.get('lon')
    radius = request.args.get('r')

    # If searching w/ params (GET)
    if request.method == 'GET' and all(v is not None for v in (latitude, longitude, radius)):
        q = "distance(location, geopoint(%f, %f)) <= %f" % (float(latitude), float(longitude), float(radius))
        index = search.Index(name="myQuestions")
        results = index.search(q)

        # TODO: replace this with a proper .query
        questions = [Question.get_by_id(long(r.doc_id)) for r in results]

        # form = QuestionForm()
        return render_template('list_questions.html', questions=questions, form=form, search_form=search_form)

    # If POSTing to create a Question
    elif request.method == 'POST' and form.validate_on_submit():
        question = Question(
            content=form.content.data,
            added_by=users.get_current_user(),
            location=get_location()
        )
        try:
            question.put()
            question_id = question.key.id()
            flash(u'Question %s successfully saved.' % question_id, 'success')
            add_question_to_search_index(question)

            return redirect(url_for('list_questions'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('list_questions'))
    return render_template('list_questions.html', questions=questions, form=form, search_form=search_form)


def get_location():
    # TODO: this should be moved to client side at some point
    return ndb.GeoPt("45.45", "23.23")


def add_question_to_search_index(question):
    index = search.Index(name="myQuestions")
    question_id = question.key.id()
    document = search.Document(
        doc_id=str(question_id),  # optional
        fields=[
            # search.TextField(name='customer', value='Joe Jackson'),
            # search.HtmlField(name='comment', value='this is <em>marked up</em> text'),
            # search.NumberField(name='number_of_visits', value=7),
            search.DateField(name='timestamp', value=question.timestamp),
            search.GeoField(name='location', value=search.GeoPoint(question.location.lat, question.location.lon))
            ])
    index.put(document)


@admin_required
def rebuild_question_search_index():
    questions = Question.all()
    [add_question_to_search_index(q) for q in questions]
    return redirect(url_for('list_questions'))


def authenticate():
    user = users.get_current_user()
    if user:
        login_url = users.create_login_url(url_for('list_examples'))
        logout_url = users.create_logout_url(login_url)
        return redirect(logout_url)
    else:
        return redirect(url_for('list_examples'))
