"""
forms.py

Web forms based on Flask-WTForms

See: http://flask.pocoo.org/docs/patterns/wtforms/
     http://wtforms.simplecodes.com/

"""

from flaskext import wtf
from flaskext.wtf import validators
from wtforms.ext.appengine.ndb import model_form

from .models import QuestionSearch
from .models import ExampleModel, Question, Answer, PostUser


class ClassicExampleForm(wtf.Form):
    example_name = wtf.TextField('Name', validators=[validators.Required()])
    example_description = wtf.TextAreaField('Description', validators=[validators.Required()])

# App Engine ndb model form example
ExampleForm = model_form(ExampleModel, wtf.Form, field_args={
    'example_name': dict(validators=[validators.Required()]),
    'example_description': dict(validators=[validators.Required()]),
})


class ClassicQuestionSearchForm(wtf.Form):
    latitude = wtf.DecimalField('Latitude',  validators=[validators.Required()])
    longitude = wtf.DecimalField('Longitude', validators=[validators.Required()])
    distance = wtf.DecimalField('Distance',  validators=[validators.Required()])

QuestionSearchForm = model_form(QuestionSearch, wtf.Form, field_args={
    'latitude': dict(validators=[validators.Required()]),
    'longitude': dict(validators=[validators.Required()]),
    'distance': dict(validators=[validators.Required()]),
})


PostUserForm = model_form(PostUser, wtf.Form, field_args={
    'login': dict(validators=[validators.Required()]),
    'screen_name': dict(validators=[validators.Required()]),
    'home_location': dict(validators=[validators.Required()]),
})

class PostForm(wtf.Form):
    content = wtf.TextField('Content', validators=[validators.Required()])

QuestionForm = model_form(Question, wtf.Form, field_args={
    'content': dict(validators=[validators.Required()]),
    'location': dict(validators=[validators.Required()]),
})

AnswerForm = model_form(Answer, wtf.Form, field_args={
    'content': dict(validators=[validators.Required()]),
    'location': dict(validators=[validators.Required()]),
})
