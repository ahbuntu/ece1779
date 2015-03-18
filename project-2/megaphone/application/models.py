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
    location = ndb.GeoPtProperty(required=False, indexed=True)

class Answer(Post):
    """A User answers a Question"""
    related_question = ndb.StructuredProperty(Post)

    @classmethod
    def answers(self):
        return []  # TODO: list all answers, ordered by date

    @classmethod
    def can_be_deleted(self):
        return True  # TODO: return false if is an accepted_answer

class Question(Post):
    """A User asks a Question"""
    accepted_answer = ndb.StructuredProperty(Answer)  # there can only be one!

    @classmethod
    def can_be_deleted(self):
        return True  # TODO: return false if is an accepted_answer

    @classmethod
    def all(self):
        return self.query()

class QuestionSearch(ndb.Model):
    latitude = ndb.FloatProperty(required=True)
    longitude = ndb.FloatProperty(required=True)
    distance = ndb.FloatProperty(required=True)
