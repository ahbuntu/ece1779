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


class Post(ndb.Model):
    """Base Model to represent questions and answers that are posted on the site"""
    added_by = ndb.UserProperty(required=True)
    content = ndb.StringProperty(indexed=True)
    timestamp = ndb.DateTimeProperty(auto_now_add=True)
    location = ndb.GeoPtProperty()


class Answer(ndb.Model):
    """A User answers a Question"""
    answer = ndb.StructuredProperty(Post)

class Question(ndb.Model):
    """A User asks a Question"""
    question = ndb.StructuredProperty(Post)
    location = ndb.GeoPtProperty(required=True)
    accepted_answer = ndb.StructuredProperty(Answer)  # there can only be one!




