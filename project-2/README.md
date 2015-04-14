# ECE1779 Project #2: Megaphone

_A location-based, community-driven question and answer service built atop Google App Engine._

## Group Information

- Group Number 5
- Group members:
    - David Carney
    - Ahmadul Hassan

## Work Breakdown

We feel that there was a 50-50 split in work/effort between the two group memebers. Please don't hesitate to ask for further details about the (long list of) tasks. We believe, however, that this is immaterial since we both agree that work was evenly divided.

## Account Instructions

Provided by email.

## In-Class Presentation

https://docs.google.com/presentation/d/1F7dg6Mazm-ZZaqPfnyF5OAsLoArRABiZPpyZ2iMjHOE/edit?usp=sharing

## Code Repository

https://github.com/dfcarney/ece1779

This document: https://github.com/dfcarney/ece1779/tree/master/project-2

## Application Overview

Megaphone is designed to be a simple service that allows (authenticated) users
to post and receive answers to location-based questions. In our initial 
implementation we only provide location-based search for world-readable questions.
Answers can only be submitted by any authenticated user.

All users see the following links in the header after logging in:

- **Nearby Activity**: Provides a list of nearby questions, with a location-based search interface.
- **My Activity**: Provides a list of the user's questions, with a location-based filter.
- **Profile**: Used to configure user settings. Currently, limited to configuring the Prospective Search area (see below for details).
- **Logout**

## Employed Technologies/Services

Here is the summary of (previously mentioned) Google App Engine technologies 
employed by Megaphone:

- Users [https://cloud.google.com/appengine/docs/python/users/]
- Deferred background jobs [https://cloud.google.com/appengine/articles/deferred]
- Channel API [https://cloud.google.com/appengine/docs/python/channel/]
- Search (specifically, building an index for use with GeoPoint searches) [https://cloud.google.com/appengine/docs/python/search/]
- Prospective Search [https://cloud.google.com/appengine/docs/python/prospectivesearch/]
- Memcached [https://cloud.google.com/appengine/docs/python/memcache/]

## Main Features

**User Authentication**

Though not really feature per se, this is important component. For this Megaphone
leverages Google App Engine's *Users API*.

_APIs employed: Users._


**Ask Question, Post Answers, Accept Answer**

Users can ask multiple 
questions. Doing so is encapsulated by creating a `Question` object. In addition
to the body of the question and a timestamp, each question has a location 
obtained from the browser (i.e. the HTML5 Geolocation API). Once created, any 
authenticated user can post `Answers` to any question. Answers also have a 
location associated with them. The owner of a question can *accept* one if 
its answers.

Note that objects (entities) are persisted using the *NDB Datastore* (and the
corresponding Python API).

_APIs employed: NDB Datastore (synchronous, asynchronous)._


**(Retroactive) Location-based Question Search**

The *Nearby Activity* page contains a simple, location-based search form that,
when submitted, performs a geo-location based search and returns all matching 
questions. On the backend this is accomplished by building a custom search
index and leveraging the built-in geo-location *Search API* provided by Google
App Engine.

_APIs employed: Search (geo-location based search, custom index), NDB Datastore._


**(Prospective) Location-based Question Search**

*Prospective Search* is an alpha-release feature provided by Google. It allows
for the real-time document-based search. When Prospective Search is configured
a callback is included, specifying the method called when a match occurs.
Within Megaphone, Prospective Search is configured to match against new 
questions that fall within each users' specified search area (configured on the
*Profile* page).

Limitations of Propspective Search, however, complicated this implementation.
In particular, there are two issues at hand:

- location-based search is not available in the Prospective Search API. This
means that for each User-Question pair an intermediate object needs to be 
created to contain the distance from one to the other. This is expensive and slow.

- search queries are static (and match against static documents). That is, 
queries cannot be defined to take an input variable. This means that distances
must be recalculated each time a given user changes their search parameters.
Again, this requires the intermediate object mentioned above.

[TODO: Ahmad, can you fill in these details and mention the related Models?]

_APIs employed: Prospective Search, NDB Datastore._


**Real-time Notifications**

Using the *Channels API*  and the *Deferred* library, Megaphone posts 
notifications about certain events:

- Users are notified about new questions matching Prospective Search.
- Users are notified of new answers to their questions.

In both cases, JavaScript parses a JSON payload sent over a channel and
performs the necessary DOM manipualtions client-side to inform the user of the
event. Generally, notifications about new questions include a URL to the question,
whereas notifications about new answers trigger an AJAX fetch of the answer,
which is then inserted into the DOM using a custom animation.

_APIs employed: Channel, Deferred Tasks._


**Other**

- Memcached was used sparingly (within `views.py`) as a proof-of-concept. See
the methods prefixed with `@cache.cached`.


## Additional Application Usage Instructions

![Nearby Activity](https://raw.githubusercontent.com/dfcarney/ece1779/master/project-2/doc/nearby%20activity.png)


## Project Organization

The project takes its form from the Flask example project, located here: https://github.com/kamalgill/flask-appengine-template.
As such, it does not follow a model-view-controller (MVC) model. While this
could be done, it was deemed not required for a project of this small size.

For a thorough introduction to Flask, see http://flask.pocoo.org/docs/0.10/

Files that saw a lot of changes during the development of Megaphone include the 
following:

- [`views.py`](https://github.com/dfcarney/ece1779/blob/master/project-2/megaphone/application/views.py): for simplicity, all logic bridging the views and models lies herein.
- [`urls.py`](https://github.com/dfcarney/ece1779/blob/master/project-2/megaphone/application/urls.py): speficies URL endpoints and routing information.
- [`models.py`](https://github.com/dfcarney/ece1779/blob/master/project-2/megaphone/application/models.py): contains model definitions for Question, Answer, etc.
- [`forms.py`](https://github.com/dfcarney/ece1779/blob/master/project-2/megaphone/application/forms.py): specifies the various `WTForms` used in the project.

## Known Issues

- Channel API handling needs to be overhauled to better track created channels
and reuse tokens, as opposed to always creating new channels/tokens. Otherwise,
the Google App Engine free-tier quotas are quickly exceeded. In a production
application, this would instead translate to a waste of money.

- Prospective Search should be performed only for registered users within the prospective search notification area. 
The current implementation naively tries to match against all registered users in the system. In a production application,
this will quickly become a bottleneck. A better approach would be to first identify users within the prospective notification area,
and then matching to see if the posted question is within a user's noification radius.

## Future Work

Some ideas for future work include the following:

- https://cloud.google.com/appengine/docs/python/memcache/ (we're already using https://pythonhosted.org/Flask-Cache/, but I don't know if it's configured)

- [TODO]

## Python Flask Resources

- http://flask.pocoo.org/docs/0.10/quickstart/
- http://blog.luisrei.com/articles/flaskrest.html
