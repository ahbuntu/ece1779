"""
models.py

App Engine datastore models

"""


from google.appengine.ext import ndb

class ExampleModel(ndb.Model):
    """Example Model"""
    example_name = ndb.StringProperty(required=True)
    example_description = ndb.TextProperty(required=True)
    added_by = ndb.UserProperty()
    timestamp = ndb.DateTimeProperty(auto_now_add=True)

class Question(ndb.Model):
    """A User asks a Question"""
    added_by = ndb.UserProperty()
    timestamp = ndb.DateTimeProperty(auto_now_add=True)
    content = ndb.StringProperty(required=True)
    location = ndb.GeoPtProperty(required=True)

class Answer(ndb.Model):
    """A User answers a Question"""
    added_by = ndb.UserProperty()
    timestamp = ndb.DateTimeProperty(auto_now_add=True)
    content = ndb.StringProperty(required=True)
    question = ndb.StructuredProperty(Question)

class Post(ndb.Model):
    """Model to represent the questions that are posted on the site"""
    author = ndb.UserProperty(required=True)
    content = ndb.StringProperty(indexed=True)
    date = ndb.DateTimeProperty(auto_now_add=True)
    location = ndb.GeoPtProperty(required=True)

