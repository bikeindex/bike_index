source 'https://rubygems.org'
ruby '2.2.5'
gem 'rails', '4.2.7'

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
gem 'sidekiq' # Background processing
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
gem 'haml-rails'
gem 'journey', '~> 1.0.3'
gem 'kramdown' # Markdown
gem 'redcarpet' # Something to do with swagger? Guess we needed another markdown parser
gem 'kaminari' # pagination
gem 'pg_search'
gem 'nokogiri'
gem 'carrierwave'
gem 'carrierwave_backgrounder'
gem 'rmagick'
gem 'mini_magick' # a smaller implementation of rmagick, required for rqrcode
gem 'rqrcode-rails3'
gem 'libv8', '~> 3.16.14.7'
gem 'stripe', git: 'https://github.com/stripe/stripe-ruby'
gem 'high_voltage'
gem 'omniauth-facebook'
gem 'omniauth-strava'
gem 'omniauth'
gem 'fog'
gem 'dalli'
gem 'draper', require: false
gem 'wkhtmltopdf-binary'
gem 'wicked_pdf'
gem 'eventmachine'
gem 'httparty'
gem 'sitemap_generator'
gem 'paranoia'

gem 'sparkpost' # ruby client for email

# OAuth provider, Grape, associated parts of API V2
gem 'doorkeeper'
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

# Show performance metrics
gem 'stackprof', require: false
gem 'memory_profiler', require: false
gem 'flamegraph', require: false
gem 'rack-mini-profiler', require: false # If you can't see it you can't make it better

gem 'responders', '~> 2.0' # required because of class level respond_to blocks (API v1)

gem 'bundler', '>= 1.8.4' # required for rails-assets.org - JS and CSS assets
source 'https://rails-assets.org' do # JS land is crazy, so lock everything
  gem 'rails-assets-lodash', '~> 4.9.0'
  gem 'rails-assets-tether', '~> 1.1.0' # Required by bootstrap 4, but not included :(
  gem 'rails-assets-mustache', '~> 2.2.1'
  gem 'rails-assets-jquery.dirtyforms', '~> 2.0.0' # Alert on attempts to leave with dirt on forms
  gem 'rails-assets-selectize', '~> 0.12.1' # Manually configured scss
  gem 'rails-assets-select2', '~> 4.0.3' # Use select2 for a few things, it's a bit better sometimes
  gem 'rails-assets-pikaday', '~> 1.4.0' # Datepicker
  gem 'rails-assets-Stickyfill', '~> 1.1.3' # Affix bike edit menu
  gem 'rails-assets-mailcheck', '~> 1.1.2' # Check for common email errors
  gem 'rails-assets-waypoints', '~> 3.1.1' # For documentation pages
  # Sortable breaks assets:precompile, so it's included manually
  # gem 'rails-assets-jquery-sortable', '~> 0.9.12' # Sort photo order
end

gem 'grape_logging' # Grape logging. Also how we pass it to lograge. Always used, not just in Prod
group :production do
  gem 'honeybadger', '~> 2.0' # Error monitoring
  gem 'lograge' # Structure log data, put it in single lines to improve the functionality
  gem 'logstash-event' # Use logstash format for logging data
  # gem 'librato-rails' # Monitoring and display
end

group :development do
  # gem 'test-unit', '~> 3.0'
  gem 'rerun'
end

group :development, :test do
  gem 'rb-fsevent', '~> 0.9.1'
  gem 'rspec', '~> 3.3.0'
  gem 'rspec-rails', '~> 3.3.0'
  gem 'shoulda-matchers', '~> 2.8.0'
  gem 'foreman'
  gem 'database_cleaner'
  gem 'dotenv-rails'
end

group :test do
  gem 'factory_girl_rails'
  gem 'codeclimate-test-reporter', require: nil
  gem 'rspec-sidekiq'
  gem 'pry'
  gem 'guard', '~> 2.13.0', require: false
  gem 'guard-rspec', '~> 4.6.4', require: false
  gem 'guard-rubocop', require: false
end