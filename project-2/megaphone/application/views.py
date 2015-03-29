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

from flask import request, render_template, flash, url_for, redirect, json

from flask_cache import Cache

from application import app
from decorators import login_required, admin_required

from forms import ExampleForm, QuestionForm, AnswerForm, QuestionSearchForm, PostUserForm

from google.appengine.api import search
from google.appengine.api import channel

# For background jobs
from google.appengine.ext import deferred
from google.appengine.runtime import DeadlineExceededError

from models import ExampleModel, Question, Answer, PostUser

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

    channel_token = channel.create_channel(all_questions_answers_channel_id())
    return render_template('list_questions.html', questions=questions, form=form, user=user, login_url=login_url, search_form=search_form, channel_token=channel_token)


def all_questions_answers_channel_id():
    return 'all-questions'


def all_user_questions_answers_channel_id(user):
    return str(user.user_id())


def question_answers_channel_id(question):
    return str(question.key.id())


@login_required
def user_profile():
    """Displays the user profile page"""
    user = users.get_current_user()
    question_count = Question.count_for(user)
    answer_count = Answer.count_for(user)
    form = PostUserForm()
    post_users = PostUser.get_for(user)
    post_user = post_users.get()

    if request.method == 'POST':
        if post_user is None:
            post_user = PostUser (
                login = user,
                home_location = get_location(form.home_location.data),
                screen_name = form.screen_name.data
            )
        else:
            post_user.home_location = get_location(form.home_location.data)
            post_user.screen_name = form.screen_name.data
        try:
            # TODO: create subscription for nearby prospective search
            post_user.put()
            flash(u'Home location successfully saved.', 'success')

            return redirect(url_for('user_profile'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('user_profile'))

    return render_template('user_profile.html', user=user, post_user=post_user,
                           question_count=question_count, answer_count=answer_count, form=form)

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

    channel_token = channel.create_channel(all_user_questions_answers_channel_id(user))
    return render_template('list_questions_for_user.html', questions=questions, form=form, user=user, login_url=login_url, search_form=search_form, channel_token=channel_token)


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

    channel_id = question_answers_channel_id(question)
    channel_token = channel.create_channel(channel_id)
    return render_template('answers_for_question.html', answers=answers, question=question, user=user, form=answerform, channel_token=channel_token)


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
            for_question=question,
            parent=question.key
        )
        try:
            answer.put()
            notify_new_answer(answer)
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


def notify_new_answer(answer):
    question_key = answer.key.parent().id()
    question = Question.get_by_id(question_key)
    question_id = question.key.id()
    title = (question.content[:20] + '...') if len(question.content) > 20 else question.content
    message = {'question_id': question_id,
               'url': url_for('answers_for_question', question_id=str(question_id)),
               'title': title}

    channel_id = question_answers_channel_id(question)
    deferred.defer(channel_send_message, channel_id, message, _countdown=2)

    channel_id = all_user_questions_answers_channel_id(question.added_by)
    deferred.defer(channel_send_message, channel_id, message, _countdown=2)

    channel_id = all_questions_answers_channel_id()
    deferred.defer(channel_send_message, channel_id, message, _countdown=2)


def channel_send_message(channel_id, message):
    tries = 1
    channel_token = channel.create_channel(channel_id)
    logging.info('starting channel_send_message')
    message_json = json.dumps(message)

    for attempt in range(tries):
        # message = 'this is message number: ' + str(attempt)
        channel.send_message(channel_id, message_json)
        logging.info('just sent: ' + message_json)
        logging.info(channel_token)


def channel_connected():
    channel = request.form['from']
    logging.info('user connected to: ' + str(channel))
    return '', 200


def channel_disconnected():
    channel = request.form['from']
    logging.info('user disconnected from: ' + str(channel))
    return '', 200
