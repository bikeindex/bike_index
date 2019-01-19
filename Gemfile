source 'https://rubygems.org'
ruby "2.5.1"
gem "rails", "4.2.10"

gem 'pg'
gem 'jquery-rails'
gem 'bcrypt', '~> 3.1.7'
gem 'active_model_serializers', '~> 0.9.3'
gem 'aws-sdk', '~> 1.33'

# Speed
gem 'fast_blank', '~> 1.0'

# Redis and redis dependents
gem 'hiredis', '~> 0.6.0'
gem 'redis', '>= 3.2.0', require: ['redis', 'redis/connection/hiredis']
gem 'sidekiq', '~> 4.2.10' # Background processing
gem 'sidekiq-failures'
gem 'rollout' # Feature flags
gem 'soulheart', '~> 0.3.0'

gem 'rack-contrib'
gem 'unicorn' # Use Puma as the app server
gem 'unicorn-worker-killer'
gem 'geocoder'
gem 'money-rails'
gem 'i18n'
gem 'hamlit'
gem 'journey', '~> 1.0.3'
gem 'kramdown' # Markdown
gem 'redcarpet' # Something to do with swagger? Guess we needed another markdown parser
gem 'kaminari' # pagination
gem 'pg_search'
gem 'nokogiri', '~> 1.8.1'
gem 'carrierwave'
gem 'carrierwave_backgrounder'
gem 'rmagick'
gem 'mini_magick' # a smaller implementation of rmagick, required for rqrcode
gem 'rqrcode-rails3'
gem 'libv8', '~> 3.16.14.7'
gem "stripe"
gem 'high_voltage'
gem 'omniauth-facebook'
gem 'omniauth-strava'
gem 'omniauth', '~> 1.3.1'
gem "fog-aws"
gem 'dalli'
gem 'draper', require: false
gem 'eventmachine'
gem 'httparty'
gem "sitemap_generator", "~> 6"
gem 'paranoia'

# Making other files
gem "wkhtmltopdf-binary"
gem "wicked_pdf"
gem "axlsx" # Write Excel files - OrganizationExports

# Rails upgrade
gem "where-or" # backports rails 5 or query support - TODO: Rails 5 update, remove

# API wrappers
gem 'twitter' # Twitter. For rendering tweets
gem 'simple_spark' # Sparkpost gem - we use it to send newsletters

# OAuth provider, Grape, associated parts of API V2
gem 'doorkeeper', '~> 3.1.0'
gem 'wine_bouncer'
gem 'grape', '~> 0.14.0'
gem 'grape-active_model_serializers', '~> 1.4.0'
gem 'grape-swagger', '~> 0.10.4'
gem 'swagger-ui_rails'
gem 'api-pagination'

# Secure things
gem 'rack-throttle'
gem 'secure_headers', '~> 2.5.0'

# Frontend
gem 'sprockets-rails', '~> 3.0.4'
gem 'coffee-rails'
gem 'therubyracer'
gem 'uglifier'
gem 'premailer-rails' # Inline styles for email
gem 'backbone-on-rails', '~>0.9.10.0' # Legacy js
gem 'chartkick' # Display charts
gem 'groupdate' # Required for charts
gem 'bootstrap', '~> 4.0.0.alpha3' # Bootstrap 4 - used for revised stylesheets
gem 'jquery-datatables-rails', '~>3.4.0'
gem 'webpacker', '~> 3.5' #Webpacker - used to transpile and compact javascript assets

# Show performance metrics
gem 'stackprof', require: false
gem 'memory_profiler', require: false
gem 'flamegraph', require: false
gem 'rack-mini-profiler', require: false # If you can't see it you can't make it better

gem 'responders', '~> 2.0' # required because of class level respond_to blocks (API v1)
gem 'thor', '0.19.1' # Locking it; http://stackoverflow.com/questions/40986923/meaning-of-expected-string-default-value-for-on-ruby-on-rails

gem 'bundler', '>= 1.8.4' # required for rails-assets.org - JS and CSS assets
source 'https://rails-assets.org' do # JS land is crazy, so lock everything
  gem 'rails-assets-lodash', '~> 4.9.0'
  gem 'rails-assets-tether', '~> 1.1.0' # Required by bootstrap 4, but not included :(
  gem 'rails-assets-mustache', '~> 2.2.1'
  gem 'rails-assets-jquery.dirtyforms', '~> 2.0.0' # Alert on attempts to leave with dirt on forms
  gem 'rails-assets-selectize', '~> 0.12.1' # Manually configured scss
  gem 'rails-assets-select2', '~> 4.0.3' # Use select2 for a few things, it's a bit better sometimes
  gem 'rails-assets-Stickyfill', '~> 1.1.3' # Affix bike edit menu
  gem 'rails-assets-mailcheck', '~> 1.1.2' # Check for common email errors
  gem 'rails-assets-waypoints', '~> 3.1.1' # For documentation pages
  gem 'rails-assets-moment', '~> 2.18.1' # Javascript Time - localizing :)
  gem 'rails-assets-moment-timezone', '~> 0.5.13' # Timezones for moment
  # Sortable breaks assets:precompile, so it's included manually
  # gem 'rails-assets-jquery-sortable', '~> 0.9.12' # Sort photo order
end

gem 'grape_logging' # Grape logging. Also how we pass it to lograge. Always used, not just in Prod
gem 'lograge' # Structure log data, put it in single lines to improve the functionality
gem 'logstash-event' # Use logstash format for logging data

group :production do
  gem "honeybadger", "~> 2.0" # Error monitoring
  gem "skylight" # Performance monitoring
end

group :development do
  # gem 'test-unit', '~> 3.0'
  gem 'rerun'
end

group :development, :test do
  gem "rb-fsevent", "~> 0.9.1"
  gem "rspec", "~> 3.3.0"
  gem "rspec-rails", "~> 3.3.0"
  gem "rspec_junit_formatter" # For circle ci
  gem "shoulda-matchers", "~> 2.8.0"
  gem "foreman"
  gem "database_cleaner"
  gem "dotenv-rails"
end

group :test do
  gem "simplecov", require: false
  gem "factory_bot_rails"
  gem "rspec-sidekiq"
  gem "guard"
  gem "guard-rspec"
  gem "guard-rubocop", require: false
  gem "vcr" # Stub external HTTP requests
  gem "webmock" # mocking for VCR
end
