# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:gitlab) { |repo| "https://gitlab.com/#{repo}.git" }

# Update CircleCI config if Ruby version is bumped
ruby "2.7.6"
gem "rack", "2.2.3"
gem "rails", "~> 6.0"

gem "puma" # App server
gem "bcrypt", "~> 3.1.7" # encryption
gem "bootsnap" # Faster bootup
gem "pg", "~> 1.0" # Postgres
gem "paranoia"
gem "pg_search"

# Speed
gem "fast_blank", "~> 1.0"
gem "active_model_serializers", "~> 0.8.3" # NOTE: more recent versions are slower, see discourse Gemfile
gem "oj" # optimized json
gem "multi_json" # TODO: use this more

# Feature flagging
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"

# I18n - localization/translation
gem "i18n-country-translations"
gem "i18n-js"
gem "rails-i18n"
gem "translation"

# Redis and redis dependents
gem "redis"
gem "sidekiq" # Background job processing
gem "sidekiq-failures" # Sidekiq failure tracking and viewing
# soulheart on branch because github.com/sethherr/soulheart/pull/32
gem "soulheart", github: "sethherr/soulheart", branch: "non-hiredis" # Autocomplete loader

gem "eventmachine"
gem "faraday_middleware" # Manage faraday request flow
gem "geocoder"
gem "hamlit" # Faster haml, what we use for templating
gem "httparty"
gem "kaminari" # pagination
gem "kramdown", "2.3.1" # Markdown
gem "kramdown-parser-gfm" # Parser required to render grape-swagger
gem "money-rails", "~> 1.11"
gem "omniauth", "~> 1.6"
gem "omniauth-facebook"
gem "omniauth-globalid"
gem "omniauth-strava"
gem "omniauth-twitter"
gem "sitemap_generator", "~> 6"

# Making other files
gem "mini_magick" # Required for image processing
gem "carrierwave", "~> 0.11.2" # File uploader
gem "carrierwave_backgrounder" # background processing of images
gem "axlsx", "~> 3.0.0.pre" # Write Excel files (OrganizationExports), on pre b/c gem isn't otherwise updated
# gem "wicked_pdf" # TODO: PDFs are broken right now - commented out because they're unused
# gem "wkhtmltopdf-binary" # TODO: PDFs are broken right now - commented out because they're unused
gem "rqrcode", "0.10.1" # QR Codes

# API wrappers
gem "twitter" # Twitter. For rendering tweets
gem "twilio-ruby" # Twilio, for verifying phone numbers
gem "stripe" # Payments
gem "fog-aws" # Aws used with carrierwave for S3 to store images
gem "postmark-rails" # Transactional email
gem "MailchimpMarketing", github: "mailchimp/mailchimp-marketing-ruby" # Marketing emails
gem "facebookbusiness", github: "facebook/facebook-ruby-business-sdk", branch: "main" # For promoted alerts

# OAuth provider, Grape, associated parts of API V2
gem "api-pagination"
gem "doorkeeper", "~> 5.2.5" # OAuth providing
gem "doorkeeper-i18n" # Translations for doorkeeper
gem "grape", "~> 1.3.0" # API DSL
gem "grape-swagger", "0.11" # auto generate swagger (OpenAPI)
gem "hashie" # required for some Grape endpoints
gem "swagger-ui_rails", github: "bikeindex/swagger-ui_rails", branch: "bike_index_0.1.7"

# Secure things
gem "rack-throttle" # Rate limiting
gem "secure_headers", "~> 2.5.0"

# Frontend
gem "jquery-rails" # Javascript framework?
gem "bootstrap", "4.0.0.alpha4" # Bootstrap 4 - used for revised stylesheets (locked to current version)
gem "chartkick" # Display charts
gem "coderay" # Pretty print code
gem "coffee-rails"
gem "groupdate" # Required for charts
gem "premailer-rails" # Inline styles for email, also auto-generates text versions of emails
gem "sass-rails"
gem "sprockets", "4.0.0"
gem "sprockets-rails"
gem "uglifier"
gem "webpacker"

# Show performance metrics
gem "flamegraph", require: false
gem "memory_profiler", require: false
gem "rack-mini-profiler", require: ["prepend_net_http_patch"] # If you can't see it you can't make it better
gem "stackprof", require: false

gem "responders"
gem "thor"

source "https://rails-assets.org" do # JS land is crazy, so lock everything
  gem "rails-assets-jquery", "~> 3.4.1"
  gem "rails-assets-jquery.dirtyforms", "~> 2.0.0" # Alert on attempts to leave with dirt on forms
  gem "rails-assets-lodash", "~> 4.9.0"
  gem "rails-assets-mailcheck", "~> 1.1.2" # Check for common email errors
  gem "rails-assets-moment", "~> 2.18.1" # Javascript Time - localizing :)
  gem "rails-assets-moment-timezone", "~> 0.5.13" # Timezones for moment
  gem "rails-assets-mustache", "~> 2.2.1"
  gem "rails-assets-select2", "~> 4.0.3" # Use select2 for a few things, it's a bit better sometimes
  gem "rails-assets-selectize", "~> 0.12.1" # Manually configured scss
  gem "rails-assets-Stickyfill", "~> 1.1.3" # Affix bike edit menu
  gem "rails-assets-tether", "~> 1.1.0" # Required by bootstrap 4, but not included :(
  gem "rails-assets-waypoints", "~> 3.1.1" # For documentation pages
  # Sortable breaks assets:precompile, so it's included manually
  # gem 'rails-assets-jquery-sortable', '~> 0.9.12' # Sort photo order
end

gem "grape_logging" # Grape logging. Also how we pass it to lograge. Always used, not just in Prod
gem "lograge" # Structure log data, put it in single lines to improve the functionality
gem "logstash-event" # Use logstash format for logging data

group :production do
  gem "skylight" # Performance monitoring
  gem "honeybadger" # Error monitoring
end

group :development do
  gem "bullet"
  # Extra faraday response logging. Used in exchange rate api client and external registry
  # Commented out because of facebook upgrade
  # gem "faraday-request_response_logger", github: "pramod-sharma/faraday-request_response_logger"
  gem "guard", require: false
  gem "guard-rspec", require: false
  gem "letter_opener"
  gem "rerun"
  gem "terminal-notifier"
end

group :development, :test do
  gem "database_cleaner"
  gem "dotenv-rails"
  gem "foreman"
  # Commented out because jazz_fingers relies on pry-coolline, which currently errors on load
  # the gem version hasn't been updated in a long time github.com/pry/pry-coolline/issues/22
  # https://github.com/pry/pry-coolline/commit/f3a130c9829969732977015a04e90b9fb5d281b2
  # gem "jazz_fingers"
  gem "parallel_tests"
  gem "pry-byebug"
  gem "pry-rails"
  gem "rb-fsevent", "~> 0.10.3"
  gem "rspec", "~> 3.4"
  gem "rspec-rails", "~> 4.0"
  gem "rspec_junit_formatter" # For circle ci
  gem "standard" # Ruby linter
  # I18n - localization/translation
  gem "i18n-tasks"
  gem "i18n_generators"
end

group :test do
  gem "factory_bot_rails"
  gem "rails-controller-testing"
  gem "rspec-sidekiq"
  gem "simplecov", require: false
  gem "vcr" # Stub external HTTP requests
  gem "webmock" # mocking for VCR
end

gem "dockerfile-rails", ">= 1.5", group: :development
