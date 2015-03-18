"""
urls.py

URL dispatch route mappings and error handlers

"""
from flask import render_template

from application import app
from application import views


## URL dispatch rules
# App Engine warm up handler
# See http://code.google.com/appengine/docs/python/config/appconfig.html#Warming_Requests
app.add_url_rule('/_ah/warmup', 'warmup', view_func=views.warmup)

# Home page
app.add_url_rule('/', 'home', view_func=views.home)

# Say hello
app.add_url_rule('/hello/<username>', 'say_hello', view_func=views.say_hello)

# Examples list page
app.add_url_rule('/examples', 'list_examples', view_func=views.list_examples, methods=['GET', 'POST'])

# Examples list page (cached)
app.add_url_rule('/examples/cached', 'cached_examples', view_func=views.cached_examples, methods=['GET'])

# Contrived admin-only view example
app.add_url_rule('/admin_only', 'admin_only', view_func=views.admin_only)

# Edit an example
app.add_url_rule('/examples/<int:example_id>/edit', 'edit_example', view_func=views.edit_example, methods=['GET', 'POST'])

# Delete an example
app.add_url_rule('/examples/<int:example_id>/delete', view_func=views.delete_example, methods=['POST'])

# List all questions
app.add_url_rule('/questions', 'list_questions', view_func=views.list_questions, methods=['GET'])

# Ask a new question
app.add_url_rule('/new_question', view_func=views.new_question, methods=['POST'])

# Edit a question
app.add_url_rule('/questions/<int:question_id>/edit', 'edit_question', view_func=views.edit_question, methods=['GET', 'POST'])

# Delete a question
app.add_url_rule('/questions/<int:question_id>/delete', view_func=views.delete_question, methods=['POST'])

# List all answers related to a question
app.add_url_rule('/questions/<int:question_id>/answers', view_func=views.answers_for_question, methods=['GET', 'POST'])

# Provide a new answer
app.add_url_rule('/questions/<int:question_id>/new_answer', 'new_answer', view_func=views.new_answer, methods=['POST'])


# Search Questions list page
app.add_url_rule('/questions/search', 'search_questions', view_func=views.search_questions, methods=['POST'])

app.add_url_rule('/admin/rebuild_question_search_index', 'rebuild_question_search_index', view_func=views.rebuild_question_search_index, methods=['GET'])

# Logout
app.add_url_rule('/logout', 'authenticate', view_func=views.authenticate, methods=['GET'])


## Error handlers
# Handle 404 errors
@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

# Handle 500 errors
@app.errorhandler(500)
def server_error(e):
    return render_template('500.html'), 500

