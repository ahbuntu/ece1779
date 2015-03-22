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

import logging

from flask import request, render_template, flash, url_for, redirect

from flask_cache import Cache

from application import app
from decorators import login_required, admin_required

from forms import ExampleForm, QuestionForm, AnswerForm, QuestionSearchForm

from google.appengine.api import search
from google.appengine.api import channel

# For background jobs
from google.appengine.ext import deferred
from google.appengine.runtime import DeadlineExceededError

from models import ExampleModel, Question, Answer

# Flask-Cache (configured to use App Engine Memcache API)
cache = Cache(app)


def home():
    user = users.get_current_user()
    if user:
        return redirect(url_for('list_questions_for_user'))
    else:
        return redirect(url_for('list_questions'))


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
    """Lists all questions posted on the site - available to anonymous users"""
    form = QuestionForm()
    search_form = QuestionSearchForm()
    user = users.get_current_user()
    login_url = users.create_login_url(url_for('home'))

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
    else:
        questions = Question.all()

    channel_token = channel.create_channel('some-channel')
    deferred.defer(channel_test, channel_token, _countdown=5)
    # return render_template('Main/cycle.html', form=form, channel_token=channel_token)

    return render_template('list_questions.html', questions=questions, form=form, user=user, login_url=login_url, search_form=search_form, channel_token=channel_token)


@login_required
def list_questions_for_user():
    """Lists all questions posted by a user"""
    form = QuestionForm()
    search_form = QuestionSearchForm()
    user = users.get_current_user()
    login_url = users.create_login_url(url_for('home'))

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
    else:
        questions = Question.all_for(user)

    return render_template('list_questions_for_user.html', questions=questions, form=form, user=user, login_url=login_url, search_form=search_form)


@login_required
def new_question():
    """Creates a new question"""
    form = QuestionForm()
    if request.method == 'POST' and form.validate_on_submit():
        question = Question(
            content=form.content.data,
            added_by=users.get_current_user(),
            location=get_location(form.location.data)
        )
        try:
            question.put()
            question_id = question.key.id()
            flash(u'Question %s successfully saved.' % question_id, 'success')
            add_question_to_search_index(question)

            return redirect(url_for('list_questions_for_user'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('list_questions_for_user'))
    else:
        flash_errors(form)
        return redirect(url_for('list_questions_for_user'))


def flash_errors(form):
    for field, errors in form.errors.items():
        for error in errors:
            flash(u"Error in the %s field - %s" % (
                getattr(form, field).label.text,
                error
            ))


def get_location(coords):
    return ndb.GeoPt(coords)


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


@login_required
def edit_question(question_id):
    """Edit a question object"""
    question = Question.get_by_id(question_id)
    form = QuestionForm(obj=question)
    user = users.get_current_user()
    if request.method == "POST":
        if form.validate_on_submit():
            question.content=form.data.get('content')
            question.location=form.data.get('location')
            question.put()
            flash(u'Question %s successfully modified.' % question_id, 'success')
            return redirect(url_for('list_questions_for_user'))
    return render_template('edit_question.html', question=question, form=form, user=user)


@login_required
def delete_question(question_id):
    """Delete an example object"""
    question = Question.get_by_id(question_id)
    if request.method == "POST":
        try:
            question.key.delete()
            flash(u'Example %s successfully deleted.' % question_id, 'success')
            return redirect(url_for('list_questions_for_user'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('list_questions_for_user'))


@login_required
def answers_for_question(question_id):
    """Provides a listing of the question and all of its associated answers"""
    question = Question.get_by_id(question_id)
    user = users.get_current_user()
    answerform = AnswerForm()
    answers = Answer.answers_for(question)

    return render_template('answers_for_question.html', answers=answers, question=question, user=user, form=answerform)


@login_required
def new_answer(question_id):
    """Create a new answer corresponding to a question"""
    question = Question.get_by_id(question_id)
    answerform = AnswerForm()
    if request.method == "POST" and answerform.validate_on_submit():
        answer = Answer(
            content=answerform.content.data,
            added_by=users.get_current_user(),
            location=get_location(answerform.location.data),
            for_question=question
        )
        try:
            answer.put()
            answer_id = answer.key.id()
            flash(u'Answer %s successfully saved.' % answer_id, 'success')
            return redirect(url_for('answers_for_question', question_id=question_id))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('answers_for_question', question_id=question_id))

    return render_template('new_answer.html', question=question, form=answerform)


@login_required
def accept_answer_for_question(question_id, answer_id):
    """Accept the answer for a questions"""
    answer = Answer.get_by_id(answer_id)
    question = Question.get_by_id(question_id)
    # questionform = QuestionForm(obj=question)
    if request.method == "POST":
        # if questionform.validate_on_submit():
        question.accepted_answer=answer
        question.put()
        flash(u'Answer %s successfully accepted.' % question_id, 'success')
        return redirect(url_for('answers_for_question', question_id=question_id))
    return redirect(url_for('answers_for_question', question_id=question_id))

@admin_required
def rebuild_question_search_index():
    questions = Question.all()
    [add_question_to_search_index(q) for q in questions]
    return redirect(url_for('list_questions'))


def authenticate():
    user = users.get_current_user()
    if user:
        login_url = users.create_login_url(url_for('home'))
        logout_url = users.create_logout_url(login_url)
        return redirect(logout_url)
    else:
        return redirect(url_for('home'))


def login():
    user = users.get_current_user()
    if user:
        return redirect('/')
    else:
        login_url = users.create_login_url(url_for('home'))
        return redirect(login_url)


def channel_test(channel_token):
    tries = 1
    logging.info('starting channel_test')
    for attempt in range(tries):
        message = 'this is message number: ' + str(attempt)
        channel.send_message('some-channel', message)
        logging.info('just sent: ' + message)
        logging.info(channel_token)
