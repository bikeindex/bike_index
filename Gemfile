def next?
  File.basename(__FILE__) == "Gemfile.next"
end
# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:gitlab) { |repo| "https://gitlab.com/#{repo}.git" }

# Update Vagrantfile and CircleCI config if Ruby version is bumped
ruby "2.5.5"
gem "rack", "2.0.8"

if next?
  gem 'rails', '~> 6.0', '>= 6.0.2.1'
else
  gem "rails", "5.2.4"
end

# Ten Years Rails is for Dual Booting your Upgrade
if next?
  gem 'ten_years_rails'
else
  gem 'ten_years_rails', '~> 1.0', '>= 1.0.2'
end

if next?
  gem "active_model_serializers"
else
  gem "active_model_serializers", "~> 0.9.3"
end

gem "bcrypt", "~> 3.1.7"
gem "bootsnap"
gem "jquery-rails"
gem "pg", "~> 1.0"

# Speed
gem "fast_blank", "~> 1.0"

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
gem "hiredis"
gem "redis", ">= 3.2.0", require: ["redis", "redis/connection/hiredis"]
gem "sidekiq", "~> 5.1.0" # Background processing
gem "sidekiq-failures"
gem "soulheart", "~> 0.3.0"

gem "carrierwave", "~> 0.11.2"
gem "carrierwave_backgrounder", "~> 0.4.2"
gem "dalli"
gem "draper", require: false # NB: Draper is deprecated in this project
gem "eventmachine"
gem "faraday_middleware"
gem "fog-aws"
gem "geocoder"
gem "hamlit"
gem "high_voltage"
gem "honeybadger"
gem "httparty"
gem "journey", "~> 1.0.3"
gem "kaminari" # pagination
gem "kramdown", "1.11.1" # Markdown
gem "mini_magick" # a smaller implementation of rmagick, required for rqrcode
gem "money-rails", "~> 1.11"
gem "nokogiri", ">= 1.10.4"
gem "omniauth", "~> 1.6"
gem "omniauth-facebook"
gem "omniauth-globalid"
gem "omniauth-strava"
gem "omniauth-twitter"
gem "paranoia"
gem "pg_search"
gem "puma", "~> 3.11"
gem "rack-contrib"
gem "redcarpet" # Something to do with swagger? Guess we needed another markdown parser
gem "rmagick"
gem "rqrcode", "0.10.1"
gem "rqrcode-rails3", github: "bikeindex/rqrcode-rails3"
gem "sitemap_generator", "~> 6"
gem "stripe", "~> 3.3.2"

# Making other files
gem "axlsx", "~> 3.0.0.pre" # Write Excel files (OrganizationExports), on pre b/c gem isn't otherwise updated
gem "wicked_pdf"
gem "wkhtmltopdf-binary"

# API wrappers
gem "simple_spark" # Sparkpost gem - we use it to send newsletters
gem "twitter" # Twitter. For rendering tweets

# OAuth provider, Grape, associated parts of API V2
gem "api-pagination"
gem "doorkeeper", "5.2.3"
gem "grape", "~> 0.19.1"
gem "grape-active_model_serializers", "~> 1.4.0"
gem "grape-swagger", "0.11"
gem "swagger-ui_rails", github: "bikeindex/swagger-ui_rails", branch: "bike_index_0.1.7"
gem "wine_bouncer"

# Secure things
gem "rack-throttle"
gem "secure_headers", "~> 2.5.0"

# Frontend
gem "bootstrap", "4.0.0.alpha4" # Bootstrap 4 - used for revised stylesheets (locked to current version)
gem "chartkick" # Display charts
gem "coderay" # Pretty print code
gem "coffee-rails"
gem "groupdate" # Required for charts
gem "premailer-rails" # Inline styles for email
gem "sass-rails"
gem "sprockets", "4.0.0"
gem "sprockets-rails"
gem "uglifier"
gem "webpacker"

# Show performance metrics
gem "flamegraph", require: false
gem "memory_profiler", require: false
gem "rack-mini-profiler", require: false # If you can't see it you can't make it better
gem "stackprof", require: false

if next?
  gem "responders"
else
  gem "responders", "~> 2.0" # required because of class level respond_to blocks (API v1)
end

gem "thor"

gem "bundler", ">= 1.8.4" # required for rails-assets.org - JS and CSS assets
source "https://rails-assets.org" do # JS land is crazy, so lock everything
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
end

group :development do
  gem "bullet"
  gem "faraday-request_response_logger", github: "pramod-sharma/faraday-request_response_logger"
  gem "guard"
  gem "guard-rspec", require: false
  gem "guard-rubocop", require: false
  gem "letter_opener"
  gem "parser", "2.6.3.0" # for Ruby 2.5.5. Unlock version when upgrading Ruby.
  gem "rerun"
  gem "terminal-notifier"
end

group :development, :test do
  gem "database_cleaner"
  gem "dotenv-rails"
  gem "foreman"
  gem "jazz_fingers"
  gem "parallel_tests"
  gem "pry-byebug"
  gem "pry-rails"
  gem "rb-fsevent", "~> 0.10.3"
  gem "rspec", "~> 3.4"
  gem "rspec-rails", "~> 3.8"
  gem "rspec_junit_formatter" # For circle ci
  gem "rubocop", "~> 0.67", require: false
  gem "rubocop-daemon", "~> 0.3.1", require: false
  gem "rubocop-performance", "~> 1.1.0", require: false
  gem "rufo", "~> 0.7.0", require: false
  # I18n - localization/translation
  gem "i18n-tasks"
  gem "i18n_generators"
end

group :test do
  gem "airborne"
  gem "factory_bot_rails"
  gem "rails-controller-testing"
  gem "rspec-sidekiq"
  gem "simplecov", require: false
  gem "vcr" # Stub external HTTP requests
  gem "webmock" # mocking for VCR
end
