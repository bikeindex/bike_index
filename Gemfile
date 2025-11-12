# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }
git_source(:gitlab) { |repo| "https://gitlab.com/#{repo}.git" }

ruby "3.4.7"

# Gems that are no longer in standard library as Ruby 3.4
gem "csv"
gem "observer"
gem "prime"
gem "openssl" # stuff breaks without this, 2025-10
# Maybe ^ can be removed after 3.4 upgrade? Added to silence deprecation warnings

gem "rails"

# Things to improve/extend Rails
gem "puma" # App server
gem "bcrypt" # encryption
gem "bootsnap" # Faster bootup
gem "pg" # Postgres
gem "paranoia" # soft delete
gem "pg_search"
gem "lograge" # Structure log data, put it in single lines to improve the functionality
gem "logstash-event" # Use logstash format for logging data
gem "rack-utf8_sanitizer" # prevent invalid UTF8 request errors
gem "responders" # Rails responders modules
gem "rack-throttle" # Rate limiting
gem "secure_headers", "~> 2.5.0"

# Speed, performance, etc
gem "fast_blank", "~> 1.0"
gem "active_model_serializers", "~> 0.8.3" # NOTE: more recent versions are slower, see discourse Gemfile
gem "oj" # optimized json
gem "multi_json" # TODO: use this more
gem "flamegraph", require: false
gem "memory_profiler", require: false
gem "rack-mini-profiler", require: ["prepend_net_http_patch"] # If you can't see it you can't make it better
gem "stackprof", require: false
gem "pghero" # PG Info


# I18n - localization/translation
gem "i18n-country-translations"
gem "i18n-js"
gem "rails-i18n"
gem "translation"


# Redis and Redis dependents
gem "redis"
gem "sidekiq" # Background job processing
# Sidekiq failure tracking and viewing. Broken for sidekiq 8. see github.com/mhfs/sidekiq-failures/pull/159
gem "sidekiq-failures", github: "navidemad/sidekiq-failures", branch: "feat-compatibility-sidekiq-8", ref: "63252253b1a17b7115fe086a910881467cd0e55d"
gem "redlock" # Locking


# Making other files
gem "image_processing" # what it says
gem "mini_magick" # Required for image processing
gem "ruby-vips" # Faster image processing, should eventually replace mini_magick
gem "carrierwave", "~> 2.2.6" # File uploader
# Using bikeindex fork to support rails 8
gem "carrierwave_backgrounder", github: "bikeindex/carrierwave_backgrounder" # background processing of images
gem "axlsx", "~> 3.0.0.pre" # Write Excel files (OrganizationExports), on pre b/c gem isn't otherwise updated
# gem "wicked_pdf" # TODO: PDFs are broken right now - commented out because they're unused
# gem "wkhtmltopdf-binary" # TODO: PDFs are broken right now - commented out because they're unused
gem "rqrcode", "0.10.1" # QR Code image generator


# Functionality extensions
gem "flipper" # Feature flagging
gem "flipper-active_record" # Feature flagging
gem "flipper-ui" # Feature flagging
gem "geocoder" # Geolocation using external APIs
gem "money-rails", "~> 1.11" # Money formatting
gem "sitemap_generator", "~> 6" # Make sitemaps


# API wrappers, external requests
gem "twitter" # Twitter. For rendering tweets
gem "twilio-ruby" # Twilio, for verifying phone numbers
gem "stripe" # Payments
gem "fog-aws" # Aws used with carrierwave for S3 to store images
gem "aws-sdk-s3", "1.170", require: false # Used by ActiveStorage for Cloudflare R2
gem "aws-sdk-core", "3.211" # Required for S3 compatibility, see github.com/rails/rails/issues/54374
gem "postmark-rails" # Transactional email
gem "MailchimpMarketing", github: "mailchimp/mailchimp-marketing-ruby" # Marketing emails
gem "facebookbusiness", github: "facebook/facebook-ruby-business-sdk", branch: "main" # For promoted alerts
gem "down" # used to generate a local tempfile
gem "faraday_middleware" # Manage faraday request flow
# gem "resolv-replace" # Ruby DNS resolver. Fixes IPv6 request issues


# OAuth provider, Grape, associated parts of API V2
gem "api-pagination"
gem "doorkeeper" # OAuth providing
gem "doorkeeper-i18n" # Translations for doorkeeper
gem "grape" # API DSL
gem "grape_logging" # Grape logging. Also how we pass it to lograge. Always used, not just in Prod


# Frontend
gem "chartkick" # Display charts
gem "coderay" # Pretty print code
gem "coffee-rails"
gem "groupdate" # Required for charts
gem "premailer-rails" # Inline styles for email, also auto-generates text versions of emails
gem "sprockets-rails"
gem "dartsass-rails"
gem "haml" # Template language
gem "herb" # New ERB parsing
gem "reactionview" # fancy view component stuff with Herb
gem "pagy" # pagination
gem "kramdown" # Markdown template language
gem "importmap-rails" # New JS setup
gem "turbo-rails" # Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "stimulus-rails" # Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "tailwindcss-rails" # Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "view_component" # view components!
gem "lookbook" # view_component preview
gem "inline_svg" # render SVGs inline and give them classes


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
  gem "rerun" # restart sidekiq processes in development on app change
  gem "hotwire-livereload", "~> 1.4.1" # See #2759 for reasoning on version
  gem "terminal-notifier"
  gem "annotaterb"
end

group :development, :test do
  gem "brakeman", require: false
  gem "ruby-lsp" # Ruby language server (used by editor integrations)
  gem "database_cleaner"
  gem "dotenv-rails"
  gem "factory_bot_rails"
  gem "foreman"
  gem "turbo_tests" # parallel tests
  gem "knapsack_pro" # parallel test optimization (for CI)
  gem "pry-byebug"
  gem "pry-rails"
  gem "rspec"
  gem "rspec-rails"
  gem "standard" # Ruby linter
  gem "erb-formatter" # html linter
  # I18n - localization/translation
  gem "i18n-tasks"
  gem "i18n_generators"
end

group :test do
  gem "rails-controller-testing"
  gem "rspec-sidekiq"
  gem "simplecov", require: false
  gem "simplecov_json_formatter", require: false # Fix json error
  gem "rspec-github", require: false # Rspec GitHub formatter (adds annotations to files)
  gem "rspec_junit_formatter", require: false # Rspec JUnit formatter (for test aggregation on GitHub)
  gem "vcr" # Stub external HTTP requests
  gem "webmock" # mocking for VCR
  gem "rspec-retry", require: false # Retry flaky test failures on CI
  gem "capybara" # For view components
  gem "selenium-webdriver" # For capybara
  gem "chunky_png" # used to test that generated images match their targets
end
