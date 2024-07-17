# [![BIKE INDEX][bike-index-logo]][bike-index] [![CircleCI][circleci-badge]][circleci] [![View performance data on Skylight][skylight-badge]][skylight]

[bike-index-logo]: https://github.com/bikeindex/bike_index/blob/main/bike_index.png?raw=true
[circleci]: https://circleci.com/gh/bikeindex/bike_index/tree/main
[circleci-badge]: https://circleci.com/gh/bikeindex/bike_index/tree/main.svg?style=svg
[skylight]: https://oss.skylight.io/app/applications/j93iQ4K2pxCP
[skylight-badge]: https://badges.skylight.io/status/j93iQ4K2pxCP.svg
[bike-index]: https://www.bikeindex.org

Bike registration that works: online, powerful, free.

Registering a 🚲 only takes a few minutes and gives 🚴‍♀️ a permanent record linked to their identity that proves ownership in the case of a theft.

We're an open source project. Take a gander through our code, report bugs, or download it and run it locally.

### Dependencies

_We recommend [asdf-vm](https://asdf-vm.com/#/) for managing versions of Ruby and Node. Check the [.tool-versions](.tool-versions) file to see the versions of the following dependencies that Bike Index uses._

- [Ruby 2.7](http://www.ruby-lang.org/en/)

- [Rails 5.2](http://rubyonrails.org/)

- [Node 12.18](https://nodejs.org/en/) & [yarn](https://yarnpkg.com/en/)

- PostgreSQL >= 9.6

- Imagemagick ([railscast](http://railscasts.com/episodes/374-image-manipulation?view=asciicast))

- [Sidekiq](https://github.com/mperham/sidekiq), which requires [Redis](http://redis.io/).

- Requires 1gb of ram (or at least more than 512mb)

## Running Bike Index locally

Follow [the Getting Started guide](docs/getting-started.markdown) for a complete set up. Or if you're familiar with developing Ruby on Rails applications start with these steps and a local Postgresql installation:

- `bin/setup` sets up the application and seeds:
  - Three test user accounts: admin@example.com, member@example.com, user@example.com (all have password `pleaseplease12`)
  - Gives user@example.com 50 bikes

- `bin/dev` start the server. It starts redis in the background and runs foreman with the [dev procfile](Procfile_development). If you need/prefer something else, do that. If your "something else" isn't running at localhost:3042, change the appropriate values in [Procfile_development](Procfile_development) and [.env](.env)

- Go to [localhost:3042](http://localhost:3042)

| Toggle in development | command                       | default  |
| ---------             | -------                       | -------  |
| Caching               | `bundle exec rails dev:cache` | disabled |
| [letter_opener][]     | `bin/rake dev:letter_opener`  | enabled  |
| logging with lograge  | `bin/rake dev:lograge`        | enabled  |

[letter_opener]: https://github.com/ryanb/letter_opener

## Localization

See the [localization docs](docs/localization.markdown) for details (we use [translation.io](https://translation.io/) for localization).

## Testing

We use [RSpec](https://github.com/rspec/rspec) and
[Guard](https://github.com/guard/guard) for testing.

- Run the test suite continuously in the background with `bin/guard` (watches for file changes/saves and runs those specs)

- You may have to manually add the `fuzzystrmatch` extension, which we use for
  near serial searches, to your databases. The migration should take care of
  this but sometimes doesn't. Open the databases in postgres
  (`psql bikeindex_development` and `psql bikeindex_test`) and add the extension.

  ```sql
  CREATE EXTENSION fuzzystrmatch;
  ```

We use [`parallel_tests`](https://github.com/grosser/parallel_tests/) to run the test suite in parallel. By default, this will spawn one process per CPU in your computer.

- Run all the tests in parallel with `bin/rake parallel:spec`

- Run `bin/rake parallel:prepare` to synchronize the test db schema after migrations (rather than `db:test:prepare`).

- Run specific files or test directories with `bin/parallel_rspec <FILES_OR_FOLDERS>`

- Run Guard with parallelism `bin/guard -G Guardfile_parallel`

## Code Hygiene

We use the following tools to automate code formatting and linting:

- [EditorConfig](https://editorconfig.org/)
- [StandardRB](https://github.com/testdouble/standard)
- [ESlint](https://eslint.org/)

Run `bin/lint` to automatically lint the files and/or add auto formatters to your text editor (e.g. [prettier-standard](https://github.com/sheerun/prettier-standard))

### EditorConfig

EditorConfig ensures whitespace consistency. See the [Download a
Plugin][editorconfig-plugin] section of the EditorConfig docs to find a plugin
appropriate to your editor.

[editorconfig-plugin]: https://editorconfig.org/#download

### StandardRB

StandardRB is an opinionated Ruby style guide, linter, and formatter - it is "a spiritual port of [StandardJS](https://standardjs.com/)".

See the [how do I run standard in my editor](standardrb-plugin) section of the StandardRB docs to find an appropriate plugin for on-the-fly linting.

[standardrb-plugin]: https://github.com/testdouble/standard#how-do-i-run-standard-in-my-editor

### ESLint

ESlint is configured to run on project JavaScript. To run it, issue `yarn lint`.

## Bug tracker

Have a bug or a feature request? [Open an issue](https://github.com/bikeindex/bike_index/issues/new).


## Community

Keep track of development and community news.

- Follow [@bikeindex](http://twitter.com/bikeindex) on Twitter.
- Read the [Bike Index Blog](https://bikeindex.org/blog).

## Contributing

Open a Pull request!

Don't wait until you have a finished feature before before opening the PR, unfinished pull requests are welcome! The earlier you open the pull request, the earlier it's possible to discuss the direction of the changes.

Once the PR is ready for review, request review from the relevant person.

If your pull request contains Ruby patches or features, you must include relevant Rspec tests.


... and go hard
