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

import logging, math

from flask import request, render_template, flash, url_for, redirect, json

from lib.flask_cache import Cache

from application import app
from decorators import login_required, admin_required

from forms import QuestionForm, AnswerForm, QuestionSearchForm, ProspectiveUserForm

from google.appengine.api import search, prospective_search
from google.appengine.api import channel

# For background jobs
from google.appengine.ext import deferred
from google.appengine.runtime import DeadlineExceededError

from models import Question, Answer, ProspectiveUser, ProspectiveSubscription, NearbyQuestion

# Flask-Cache (configured to use App Engine Memcache API)
cache = Cache(app)


def home():
    user = users.get_current_user()
    if user:
        return redirect(url_for('list_questions_for_user'))
    else:
        return redirect(url_for('list_questions'))


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
    radius = search_form.distance_in_km.data
    return redirect(url_for('list_questions', lat=latitude, lon=longitude, r=radius))


@admin_required
def admin_only():
    """This view requires an admin account"""
    return 'Super-seekrit admin page.'


def warmup():
    """App Engine warmup handler
    See http://code.google.com/appengine/docs/python/config/appconfig.html#Warming_Requests

    """
    return ''


@cache.cached(timeout=5)
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
        radius_in_metres = float(radius) * 1000.0
        q = "distance(location, geopoint(%f, %f)) <= %f" % (float(latitude), float(longitude), float(radius_in_metres))

        # build the index if not already done
        if search.get_indexes().__len__() == 0:
            rebuild_question_search_index()

        index = search.Index(name="myQuestions")
        results = index.search(q)

        # TODO: replace this with a proper .query
        questions = [Question.get_by_id(long(r.doc_id)) for r in results]
        questions = sorted(questions, key=lambda question: question.timestamp)

        search_form.latitude.data = float(latitude)
        search_form.longitude.data = float(longitude)
        search_form.distance_in_km.data = radius_in_metres/1000.0
    else:
        questions = Question.all()

    channel_token = None
    if (user):
        channel_token = channel.create_channel(user_channel_id(user))
    return render_template('list_questions.html', questions=questions, form=form, user=user, login_url=login_url, search_form=search_form, channel_token=channel_token)


def all_user_questions_answers_channel_id(user):
    return 'answers-' + str(user.user_id())


def question_answers_channel_id(question):
    return str(question.key.id())


def user_channel_id(user):
    return str(user.user_id())


@login_required
def user_profile():
    """Displays the user profile page"""
    user = users.get_current_user()
    question_count = Question.count_for(user)
    answer_count = Answer.count_for(user)
    form = ProspectiveUserForm()
    all_prospective_users = ProspectiveUser.get_for(user)
    prospective_user = all_prospective_users.get()

    if request.method == 'POST':
        if prospective_user is None:
            prospective_user = ProspectiveUser (
                login = user,
                origin_location = get_location(form.origin_location.data),
                notification_radius_in_km = form.notification_radius_in_km.data, #TODO: make this dynamic
                screen_name = form.screen_name.data
            )
        else:
            # all_post_users = ProspectiveUser.get_for(users.get_current_user())
            # post_user = all_post_users.get()
            prospective_user.origin_location = get_location(form.origin_location.data)
            prospective_user.notification_radius_in_km = get_location(form.notification_radius_in_km.data), #TODO: make this dynamic
            prospective_user.screen_name = form.screen_name.data
        try:
            prospective_user.put()
            subscribe_user_for_nearby_questions(prospective_user.key.id())
            flash(u'Home location successfully saved.', 'success')

            return redirect(url_for('user_profile'))
        except CapabilityDisabledError:
            flash(u'App Engine Datastore is currently in read-only mode.', 'info')
            return redirect(url_for('user_profile'))

    return render_template('user_profile.html', user=user, post_user=prospective_user,
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
        questions = sorted(questions, key=lambda question: question.timestamp)
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
            # location=get_location(form.location.data) //TODO: fix stub
            location=get_location('43.7,-80.5667')

        )
        try:
            question.put()
            question_id = question.key.id()

            create_nearby_question(question_id)

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
    """Delete a Question"""
    question = Question.get_by_id(question_id)
    if request.method == "POST":
        try:
            question.key.delete()
            flash(u'Question %s successfully deleted.' % question_id, 'success')
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


def list_subscriptions():
    """List all subscriptions"""
    subscriptions = prospective_search.list_subscriptions(
        NearbyQuestion
    )
    return render_template('list_subscriptions.html', subscriptions=subscriptions)

#
# def subscribe_for_prospective_post(post_id):
#     """Create new subscriptions for the provided question and user"""
#     sub = Pros(
#         for_post_id = post_id
#     )
#     sub.put()
#     post = ProspectiveQuestion.get_by_id(post_id)
#     prospective_search.subscribe(
#         ProspectiveQuestion,
#         post.content,
#         sub.key(),
#         lease_duration_sec=600
#     )

def match_prospective_search():
    if request.method == "POST":
        logging.info("received a match")
        webapp2Request = request.form
        nearby_question = prospective_search.get_document(webapp2Request)
        prospective_user = ProspectiveUser.get_by_id(nearby_question.for_prospective_user_id)
        question = Question.get_by_id(nearby_question.for_question_id)

        notify_new_question(prospective_user.login, question)
    return '', 200


def deg2rad(deg):
    return deg * (math.pi/180)


def get_location_distance_in_km(lat1, lon1, lat2, lon2):
    earth_radius = 6371 # Radius of the earth in km
    d_lat = deg2rad(lat2 - lat1)
    d_lon = deg2rad(lon2 - lon1)
    a = math.sin(d_lat/2) * math.sin(d_lat/2) + math.cos(deg2rad(lat1)) * math.cos(deg2rad(lat2)) * math.sin(d_lon/2) * math.sin(d_lon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    d = earth_radius * c # Distance in km
    return d


# Why do we need to create a NearbyQuestion for each ProspectiveUser/Question combo? It's obviously inefficient.
#
# Why not:
# - Questions are the documents being matched against
# - Each ProspectiveUser has a subscription (query) that matches against (new) Questions in a given radius
# - New question triggers Channel notification based on ID of ProspectiveUser
#
# Problem is that a query is static and doesn't perform any calculations/joins with other objects.
# So, if we want to search by distance to X then we have to calculate the distance for each Question
# beforehand and define a query that matches on that. This, of course, is ridiculous...but it's part
# of an experiment with Prospective Search.
def create_nearby_question(question_id):
    prospective_users = ProspectiveUser.all()
    question = Question.get_by_id(question_id)
    for user_to_test in prospective_users:

        if user_to_test.login == question.added_by:
            continue # No need to create a search for your own questions

        # create a new document and subscribe to it
        distance_to_origin = get_location_distance_in_km(user_to_test.origin_location.lat,
                                                         user_to_test.origin_location.lon,
                                                         question.location.lat,
                                                         question.location.lon)
        nearby_prospective_question = NearbyQuestion(
            for_prospective_user_id=user_to_test.key.id(),
            for_question_id=question_id,
            origin_latitude=user_to_test.origin_location.lat,
            origin_longitude=user_to_test.origin_location.lon,
            origin_radius=user_to_test.notification_radius_in_km,
            origin_distance_in_km=distance_to_origin
        )

        # TODO: (potentially) only required for debugging purposes. Prospective_search.match might not required a saved entity.
        nearby_prospective_question.put()

        # "Documents are assigned to a particular topic when calling match()"
        prospective_search.match(
            nearby_prospective_question
        )

def subscribe_user_for_nearby_questions(prospective_user_id):
    """Create new subscriptions for the provided question and user"""
    sub = ProspectiveSubscription(
        prospective_user_id = prospective_user_id
    )
    sub.put()
    prospective_user = ProspectiveUser.get_by_id(prospective_user_id)
    # nearby_question = NearbyQuestion.get_by_id(nearby_question_id)
    # query = 'origin_latitude = {:f} AND origin_longitude = {:f} AND origin_distance_in_km < {:d}'\
    #     .format(prospective_user.origin_location.lat, prospective_user.origin_location.lon, prospective_user.notification_radius_in_km)

    query = 'origin_distance_in_km < {:d}'.format(prospective_user.notification_radius_in_km)

    # "Topics are not defined as a separate step; instead, topics are created as a side effect of the subscribe() call."
    prospective_search.subscribe(
        NearbyQuestion,
        query,
        sub.key(),
        lease_duration_sec=300
    )

def notify_new_question(user, question):
    question_id = question.key.id()
    title = (question.content[:20] + '...') if len(question.content) > 20 else question.content
    url = url_for('answers_for_question', question_id=str(question_id))
    message = {'question_id': question_id,
               'url': url,
               'title': title,
               'msg': "A new question was posted ('" + title + "'). Click <a href='" + url + "'>here</a> to view it."
               }

    # For now, only broadcast to the specific user; otherwise we risk
    # duplicate notifications if this method gets called in succession

    channel_id = user_channel_id(user)
    deferred.defer(channel_send_message, channel_id, message, _countdown=2)


def notify_new_answer(answer):
    question_key = answer.key.parent().id()
    question = Question.get_by_id(question_key)
    question_id = question.key.id()
    title = (question.content[:20] + '...') if len(question.content) > 20 else question.content
    url = url_for('answers_for_question', question_id=str(question_id))
    message = {'question_id': question_id,
               'url': url,
               'title': title,
               'msg': "The question ('" + title + "') received a new answer. Click <a href='" + url + "'>here</a> to view it."
               }

    # Broadcast to all channels that care about new answers

    channel_id = question_answers_channel_id(question)
    deferred.defer(channel_send_message, channel_id, message, _countdown=2)

    channel_id = all_user_questions_answers_channel_id(question.added_by)
    deferred.defer(channel_send_message, channel_id, message, _countdown=2)

    channel_id = user_channel_id(question.added_by)
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

