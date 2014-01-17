# ![BIKE INDEX](https://github.com/bikeindex/webapp/blob/master/bike_index.png?raw=true) This is the [Bike Index](https://www.bikeindex.org) [![Build Status](https://secure.travis-ci.org/bikeindex/bike_index.png)](http://travis-ci.org/bikeindex/bike_index)

The Bike Index is a national bike registry that fights theft by working with shops and advocacy organizations to register bikes for free quickly and easily.

Registering a bike only takes a few minutes and gives cyclists a permanent record linked to their identity that proves ownership in the case of a theft.

We're an open source project. Take a gander through our code, report bugs, or download it and run it locally.

### Dependencies

- [Ruby 1.9.3](http://www.ruby-lang.org/en/) (we use [RVM](https://rvm.io/))

- [Rails 3.2](http://rubyonrails.org/)

- PostgreSQL

- Imagemagick ([railscast](http://railscasts.com/episodes/374-image-manipulation?view=asciicast))

- *If you turn on caching locally:* [Dalli](https://github.com/mperham/dalli) ([railscast](http://railscasts.com/episodes/380-memcached-dalli?view=asciicast))


## Running the Bike Index locally

- Copy `config/database-sample` to `config/database.yml`

- Create and seed your database (`rake db:setup`)

- `rake seed_test_users` to add the three test user accounts: admin@example.com, member@example.com, user@example.com (all have password `please12`)

- `rake seed_test_bikes` to give user@example.com 50 bikes

- `bundle exec foreman start` to start the server

- **Access the site through [lvh.me:3000](http://lvh.me:3000)**. You can't log in through localhost:3000.
 
  - if you want to use [pow](http://pow.cx/), change the appropriate values in `session_store.rb` and `development.rb`

- We use [RSpec](https://github.com/rspec/rspec) and [Guard](https://github.com/guard/guard) for testing. 
    
    - Run the test suit in the background with `bundle exec guard`



## Bug tracker

Have a bug or a feature request? [Open a new issue](https://github.com/bikeindex/bike_index/issues).


## Community

Keep track of development and community news.

- Follow [@bikeindex](http://twitter.com/bikeindex) on Twitter.
- Read the [Bike Index Blog](https://bikeindex.org/blog).
- Have a question that's not a feature request or bug report? Ask on the [mailing list](https://groups.google.com/group/bike-index).


## Contributing

Please submit all pull requests as *_wip branches. If your pull request contains Ruby patches or features, you must include relevant rspec tests.



and go hard