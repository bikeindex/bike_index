# ![BIKE INDEX](https://github.com/bikeindex/webapp/blob/master/bike_index.png?raw=true) This is the [Bike Index](https://www.bikeindex.org) [![Build Status](https://secure.travis-ci.org/bikeindex/webapp.png)](http://travis-ci.org/bikeindex/webapp)



## Dependencies

- [Ruby 1.9.3](http://www.ruby-lang.org/en/) (we use [RVM](https://rvm.io/))

- [Rails 3.2](http://rubyonrails.org/)

- PostgreSQL

- Imagemagick ([railscast](http://railscasts.com/episodes/374-image-manipulation?view=asciicast))

- *If you turn on caching locally:* [Dalli](https://github.com/mperham/dalli) ([railscast](http://railscasts.com/episodes/380-memcached-dalli?view=asciicast))


## Run it

- Create and seed your database (`rake db:setup`)

- `rake seed_test_users` to add the three test user accounts: admin@example.com, member@example.com, user@example.com (all have password `please12`)

- `rake seed_test_bikes` to give user@example.com 50 bikes

- `bundle exec foreman start` to start the server

- **Access the site through [lvh.me:3000](http://lvh.me:300)**. You can't log in through localhost:3000.
 
  - if you want to use [pow](http://pow.cx/), change the appropriate values in `session_store.rb` and `development.rb`

- We use [RSpec](https://github.com/rspec/rspec) and [Guard](https://github.com/guard/guard) for testing. 
    
    - Run the test suit in the background with `bundle exec guard`



## Bug tracker

Have a bug or a feature request? [Open a new issue](https://github.com/bikeindex/webapp/issues).


## Community

Keep track of development and community news.

- Follow [@bikeindex](http://twitter.com/bikeindex) on Twitter.
- Read the [Bike Index Blog](https://bikeindex.org/blog).


## Contributing

Please submit all pull requests as *_wip branches. If your pull request contains Ruby patches or features, you must include relevant rspec tests.



and go hard