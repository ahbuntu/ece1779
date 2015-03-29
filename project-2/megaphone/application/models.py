"""
models.py

App Engine datastore models

"""


from google.appengine.ext import ndb, db

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
    for_question = ndb.StructuredProperty(Post)

    @classmethod
    def answers_for(self, question):
        return self.query(self.for_question == question).order(self.timestamp) # oldest first

    @classmethod
    def all(self):
        return self.query()

    @classmethod
    def count_for(self, user):
        return self.query(self.added_by == user).count()

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
        return self.query().order(-self.timestamp) # newest first

    @classmethod
    def all_for(self, user):
        return self.query(self.added_by == user).order(-self.timestamp) # newest first

    @classmethod
    def count_for(self, user):
        return self.query(self.added_by == user).count()

class QuestionSearch(ndb.Model):
    latitude = ndb.FloatProperty(required=True)
    longitude = ndb.FloatProperty(required=True)
    distance = ndb.FloatProperty(required=True)

class RelatedQuestion(db.Model):
    content = db.StringProperty(required=True)

class SubscriptionRelatedQuestions(db.Model):
    """Provides information on a subscription for a question."""
    for_question_id = db.IntegerProperty(required=True)
    created = db.DateTimeProperty(required=True, auto_now=True)
