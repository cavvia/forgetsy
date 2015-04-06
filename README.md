Forgetsy
=======

Forgetsy is a scalable trending library designed to track temporal trends in non-stationary categorical distributions. It uses [forget-table](https://github.com/bitly/forgettable/) style data structures which decay observations over time. Using two such sets decaying over different lifetimes, it picks up on changes to recent dynamics in your observations, whilst forgetting historical data responsibly.

Trends are encapsulated by a construct named Delta. A Delta consists of two sets of counters, each of which implements exponential decay of the form:

![equation](http://latex.codecogs.com/gif.latex?X_t_1%3DX_t_0%5Ctimes%7Be%5E%7B-%5Clambda%5Ctimes%7Bt%7D%7D%7D)

Where the inverse of the _decay rate_ (lambda) is the mean lifetime of an observation in the set. By normalising such a set by a set with half the decay rate, we obtain a trending score for each category in a distribution. This score expresses the change in the rate of observations of a category over the lifetime of the set, as a proportion in the range 0..1.

Forgetsy removes the need for manually sliding time windows or explicitly maintaining rolling counts, as observations naturally decay away over time. It's designed for heavy writes and sparse reads, as it implements decay at read time.

Each set is implemented as a redis `sorted set`, and keys are scrubbed when a count is decayed to near zero, providing storage efficiency.

Forgetsy handles distributions with upto around 10<sup>6</sup> active categories, receiving hundreds of writes per second, without much fuss. Its scalability is dependent on your redis deployment.

It requires [redis](https://github.com/antirez/redis) to be running on localhost at the default port (6379).

Installation
------------

Add this to your Gemfile:

```ruby
gem 'forgetsy', github: 'cavvia/forgetsy', branch: 'v0.2.5'
```

Configuration
-----

You may want to change the Redis host and port Forgetsy connects to, or
set various other options at startup.

Forgetsy has a `redis` setter which can be given a string or a Redis
object. This means if you're already using Redis in your app, Forgetsy
can re-use the existing connection.

String: `Forgetsy.redis = 'localhost:6379'`

Redis: `Forgetsy.redis = Redis.current`


Usage
-----

Take, for example, a social network in which users can follow each other. You want to track trending users. You construct a one week delta, to capture trends in your follows data over one week periods:
```ruby
follows_delta = Forgetsy::Delta.create('user_follows', t: 1.week)
```
The delta consists of two sets of counters indexed by category identifiers. In this example, the identifiers will be user ids. One set decays over the mean lifetime specified by _t_, and another set decays over double the lifetime.

You can now add observations to the delta, in the form of follow events. Each time a user follows another, you increment the followed user id. You can also do this retrospectively:
```ruby
follows_delta = Forgetsy::Delta.fetch('user_follows')
follows_delta.incr('UserFoo', date: 2.weeks.ago)
follows_delta.incr('UserBar', date: 10.days.ago)
follows_delta.incr('UserBar', date: 1.week.ago)
follows_delta.incr('UserFoo', date: 1.day.ago)
follows_delta.incr('UserFoo')
```
Providing an explicit date is useful if you are processing data asynchronously. You can also use `incr_by` to increment a counter in batches.

You can now consult your follows delta to find your top trending users:
```ruby
puts follows_delta.fetch
```
Will print:
```ruby
{ 'UserFoo' => 0.789, 'UserBar' => 0.367 }
```
Each user is given a dimensionless score in the range 0..1 corresponding to the normalised follows delta over the time period. This expresses the proportion of follows gained by the user over the last week compared to double that lifetime.

Optionally fetch the top _n_ users, or an individual user's trending score:
```ruby
follows_delta.fetch(n: 20)
follows_delta.fetch(bin: 'UserFoo')
```
Contributing
------------

Just fork the repo and submit a pull request.

Copyright & License
-------------------
MIT license. See [LICENSE](LICENSE) for details.

(c) 2013 [Art.sy Inc.](http://artsy.github.com)
