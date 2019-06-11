# <p align="center">![BIKE INDEX][bike-index-logo]</p> [Bike Index][bike-index] 🚲 ![Cloud66 Deployment Status][cloud66-badge] [![CircleCI][circleci-badge]][circleci] [![Test Coverage][codeclimate-badge]][codeclimate] [![View performance data on Skylight][skylight-badge]][skylight]

[bike-index-logo]: https://github.com/bikeindex/bike_index/blob/master/bike_index.png?raw=true
[circleci]: https://circleci.com/gh/bikeindex/bike_index/tree/master
[circleci-badge]: https://circleci.com/gh/bikeindex/bike_index/tree/master.svg?style=svg
[codeclimate]: https://codeclimate.com/github/bikeindex/bike_index
[codeclimate-badge]: https://codeclimate.com/github/bikeindex/bike_index/badges/coverage.svg
[skylight]: https://oss.skylight.io/app/applications/j93iQ4K2pxCP
[skylight-badge]: https://badges.skylight.io/status/j93iQ4K2pxCP.svg
[bike-index]: https://www.bikeindex.org
[cloud66-badge]: https://app.cloud66.com/stacks/badge/ff54cf1d55d7eb91ef09c90f125ae4f1.svg

Bike registration that works: online, powerful, free.

Registering a bike only takes a few minutes and gives cyclists a permanent record linked to their identity that proves ownership in the case of a theft.

We're an open source project. Take a gander through our code, report bugs, or download it and run it locally.

### Dependencies

- [Ruby 2.5.1](http://www.ruby-lang.org/en/) (we use [RVM](https://rvm.io/))

- [Rails 4.2](http://rubyonrails.org/)

- [Node 10.13.0](https://nodejs.org/en/) & [yarn](https://yarnpkg.com/en/) (We use [nvm](https://github.com/creationix/nvm) to manage our node version)

- PostgreSQL >= 9.6

- Imagemagick ([railscast](http://railscasts.com/episodes/374-image-manipulation?view=asciicast))

- [Sidekiq](https://github.com/mperham/sidekiq), which requires [Redis](http://redis.io/). The [RailsCast on Resque](http://railscasts.com/episodes/271-resque?view=asciicast) is a good resource for getting up and running with Redis.

- *If you turn on caching locally:* [Dalli](https://github.com/mperham/dalli) ([railscast](http://railscasts.com/episodes/380-memcached-dalli?view=asciicast) - you will need to install and start memcached `/usr/local/bin/memcached`)

- Requires 1gb of ram (or at least more than 512mb)


## Running Bike Index locally

This explanation assumes you're familiar with developing Ruby on Rails applications.

- `bundle install` install ruby gems

- `yarn install` install js packages

- `bin/rake db:setup` create and seed your database

- `bin/rake seed_test_users_and_bikes` to:
  - Add the three test user accounts: admin@example.com, member@example.com, user@example.com (all have password `please12`)
  - Give user@example.com 50 bikes

- `./start` start the server.

  - [start](start) is a bash script. It starts redis in the background and runs foreman with the [dev procfile](Procfile_development). If you need/prefer something else, do that

- Go to [localhost:3001](http://localhost:3001)

  - if you want to use [Pow](http://pow.cx/) (or some other setup that isn't through localhost:3001), change the appropriate values in [session_store.rb](config/initializers/session_store.rb) and [.env](.env).


Toggle Spring with `rake dev:spring` (defaults to disabled)

Toggle Caching in development with `rake dev:cache` (defaults to disabled)


## Testing

We use [RSpec](https://github.com/rspec/rspec) and
[Guard](https://github.com/guard/guard) for testing.

- Run the test suite continuously in the background with `bin/guard`.

- Run the entire test suite in parallel (see "Running tests in parallel" below)
  with `bin/rake parallel:spec`.

- Run a list of test files or test directories in parallel with
  `bin/parallel_rspec <FILES_OR_FOLDERS>`.

- Run tests sequentially with `bin/rspec`.

- You may have to manually add the `fuzzystrmatch` extension, which we use for
  near serial searches, to your databases. The migration should take care of
  this but sometimes doesn't. Open the databases in postgres
  (`psql bikeindex_development` and `psql bikeindex_test`) and add the extension.

  ```sql
  CREATE EXTENSION fuzzystrmatch;
  ```

### Running tests in parallel

The project's test suite can be run in parallel using [`parallel_tests`][]. By
default, the library spawns one process per CPU. You can optionally set the
`PARALLEL_TEST_PROCESSORS` env variable to tweak this number, or set it from the
command line by issuing

```shell-script
bin/rake parallel:test[1] # --> force 1 CPU
```

You may need to experiment to find the optimal number, but the library provides
a sensible default of 1 per CPU (2 per dual-core processor, e.g.).

The first time you run tests in parallel you'll need to set up your test
databases with

```shell-script
bin/rake parallel:setup
```

You'll then be able to run the test suite in parallel with

```shell-script
bin/rake parallel:spec
```

To manually propagate migrations across all test databases, issue

```shell-script
bin/rake parallel:prepare
```

See the [`parallel_tests`][] docs for more.

[`parallel_tests`]: https://github.com/grosser/parallel_tests/

## Code Hygiene

We use the following tools to automate code formatting and linting:

- [EditorConfig](https://editorconfig.org/)
- [Rufo](https://github.com/ruby-formatter/rufo)
- [Rubocop](https://github.com/rubocop-hq/rubocop)
- [ESlint](https://eslint.org/)

### EditorConfig

EditorConfig ensures whitespace consistency. See the [Download a
Plugin][editorconfig-plugin] section of the EditorConfig docs to find a plugin
appropriate to your editor.

[editorconfig-plugin]: https://editorconfig.org/#download

### Rufo

Rufo is an opinionated Ruby formatter we use to maintain consistent style with
minimum configuration. See the [Editor support][rufo-plugin] section of the
project README to find a suitable editor plugin.

[rufo-plugin]: https://github.com/ruby-formatter/rufo#editor-support

### RuboCop

RuboCop is configured to ignore Ruby style and layout (deferring to Rufo) and focus
on code complexity, performance, and suggested best practices.

To run it from the command line, issue `bin/rubocop`, optionally passing
a specific file(s). For a performance boost, you can also start a rubocop daemon
with `bundle exec rubocop-daemon start`, in which case you'd lint with
`bundle exec rubocop-daemon exec`.

See the [Editor integration][rubocop-editor] section of the rubocop docs to find
an appropriate plugin for on-the-fly linting.

[rubocop-editor]: https://rubocop.readthedocs.io/en/latest/integration_with_other_tools/#editor-integration

### ESLint

ESlint is configured to run on project JavaScript. To run it, issue `yarn lint`.

## Vagrant development box

In general, we recommend installing and running the app without Vagrant for local development

If, however, you would prefer to have a virtual environment, this repository contains a Vagrantfile which is used to automatically set up and configure a virtual local (Ubuntu Xenial) development environment with all of the required dependencies preinstalled.

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

Open a Pull request!

Don't wait until you have a finished feature before before opening the PR, unfinished pull requests are welcome! The earlier you open the pull request, the earlier it's possible to discuss the direction of the changes.

Once the PR is ready for review, request review from the relevant person.

If your pull request contains Ruby patches or features, you must include relevant rspec tests.


... and go hard
