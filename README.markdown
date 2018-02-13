# ![BIKE INDEX](https://github.com/bikeindex/bike_index/blob/master/bike_index.png?raw=true) This is the [Bike Index](https://www.bikeindex.org) [![Build Status](https://travis-ci.org/bikeindex/bike_index.svg?branch=master)](https://travis-ci.org/bikeindex/bike_index)
[![Code Climate](https://codeclimate.com/github/bikeindex/bike_index/badges/gpa.svg)](https://codeclimate.com/github/bikeindex/bike_index)
[![Test Coverage](https://codeclimate.com/github/bikeindex/bike_index/badges/coverage.svg)](https://codeclimate.com/github/bikeindex/bike_index)

Bike registration that works: online, powerful, free.

Registering a bike only takes a few minutes and gives cyclists a permanent record linked to their identity that proves ownership in the case of a theft.

We're an open source project. Take a gander through our code, report bugs, or download it and run it locally.

### Dependencies

- [Ruby 2.2.5](http://www.ruby-lang.org/en/) (we use [RVM](https://rvm.io/))

- [Rails 4.2](http://rubyonrails.org/)

- PostgreSQL >= 9.6

- Imagemagick ([railscast](http://railscasts.com/episodes/374-image-manipulation?view=asciicast))

- [Sidekiq](https://github.com/mperham/sidekiq), which requires [Redis](http://redis.io/). The [RailsCast on Resque](http://railscasts.com/episodes/271-resque?view=asciicast) is a good resource for getting up and running with Redis.

- *If you turn on caching locally:* [Dalli](https://github.com/mperham/dalli) ([railscast](http://railscasts.com/episodes/380-memcached-dalli?view=asciicast) - you will need to install and start memcached `/usr/local/bin/memcached`)

- Requires 1gb of ram (or at least more than 512mb)


## Running Bike Index locally

This explanation assumes you're familiar with developing Ruby on Rails applications.

- `bundle install` install gems

- `rake db:setup` create and seed your database

- `rake seed_test_users_and_bikes` to:
  - Add the three test user accounts: admin@example.com, member@example.com, user@example.com (all have password `please12`)
  - Give user@example.com 50 bikes

- `./start` start the server.

  - [start](start) is a bash script. It starts redis in the background and runs foreman with the [dev procfile](Procfile_development). If you need/prefer something else, do that

- Go to [localhost:3001](http://localhost:3001)

  - if you want to use [Pow](http://pow.cx/) (or some other setup that isn't through localhost:3001), change the appropriate values in [session_store.rb](config/initializers/session_store.rb) and [.env](.env).


## Testing
 
We use [RSpec](https://github.com/rspec/rspec) and [Guard](https://github.com/guard/guard) for testing.
    
- Run the test suit in the background with `bundle exec guard`

- You may have to manually add the fuzzystrmatch extension, which we use for near serial searches, to your databases. The migration should take care of this but sometimes doesn't. Open the databases in postgres (`psql bikeindex_development` and `psql bikeindex_test`) and add the extension.
    
```
CREATE EXTENSION fuzzystrmatch;
```

- If you're working on frontend development, you can use [Guard::LiveReload](https://github.com/guard/guard-livereload) to reload the frontend as you work with `bundle exec guard -G Guardfile_frontend`

## Vagrant development box

For your convenience, this repository contains a Vagrantfile which is used to automatically set up and configure a virtual local (Ubuntu Xenial) development environment with all of the required dependencies preinstalled.

### Dependencies/Requirements
- A computer that supports hardware virtualization (Intel VT-x/AMD-V)

- Vagrant

- VirtualBox

- At least 1.5GB of free memory

Run `vagrant up` to start the virtual machine. Upon first run, it will run various provisioning scripts to install all of the required packages, configure PostgreSQL, and run all of the Ruby commands to initalize a local Bike Index dev environment. Port 3001 is forwarded locally for testing. Be warned, it will take around a half hour or longer (depending on your internet connection) on first run to download additional Vagrant dependencies and to provision the dev environment. You may observe some informational warning messages during the initial setup which you can safely ignore. `vagrant halt` to shutdown the VM. Subsequent startups will take considerably less time after the initial run.

### Troubleshooting
If the initial provisioning fails for any reason, try running `vagrant provision` and see if running the provisioner again completes without error. If not, please try to troubleshoot/google issues as much as possible before filing an issue. Many Vagrant related errors/issues have already been solved and are documented between Stackoverflow and Github. If you run in to an issue you're unable to solve, be sure to include all relevant stdout messages and errors.

## Bug tracker

Have a bug or a feature request? [Open a new issue](https://github.com/bikeindex/bike_index/issues/new).


## Community

Keep track of development and community news.

- Follow [@bikeindex](http://twitter.com/bikeindex) on Twitter.
- Read the [Bike Index Blog](https://bikeindex.org/blog).

## Contributing

Open a Pull request! The earlier you open the pull request, the earlier it's possible to discuss the direction of the changes.

If your pull request contains Ruby patches or features, you must include relevant rspec tests.



... and go hard
