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
from .models import Question, Answer

class ClassicQuestionSearchForm(wtf.Form):
    latitude = wtf.DecimalField('Latitude',  validators=[validators.Required()])
    longitude = wtf.DecimalField('Longitude', validators=[validators.Required()])
    distance_in_km = wtf.DecimalField('Distance (km)',  validators=[validators.Required()])

QuestionSearchForm = model_form(QuestionSearch, wtf.Form, field_args={
    'latitude': dict(validators=[validators.Required()]),
    'longitude': dict(validators=[validators.Required()]),
    'distance_in_km': dict(validators=[validators.Required()]),
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
