source 'https://rubygems.org'
ruby '2.1.3'

gem 'rails', '3.2.22'

gem 'pg'
gem 'jquery-rails'
gem 'bcrypt-ruby', '~> 3.0.0'
gem 'active_model_serializers'
gem 'aws-sdk', '~> 1.3.4'

# Speed
gem 'fast_blank', '~> 1.0'

# Redis and redis dependents
gem 'redis'
gem 'sidekiq', '~> 4.1.1' # Background processing
gem 'sidekiq-failures'
gem 'sidekiq-unique-jobs'
gem 'rollout' # Feature flags
gem 'soulheart', '~> 0.2.6' # typeahead/autocomplete features

gem 'rack-contrib'
gem 'geocoder'
gem 'money-rails', '~> 0.5.0'
gem 'i18n'
gem 'hamlit'
gem 'haml-rails'
gem 'journey', '~> 1.0.3'
gem 'kramdown'
gem 'kaminari' # pagination
gem 'pg_search'
gem 'nokogiri'
gem 'carrierwave', '~> 0.9.0'
gem 'carrierwave_backgrounder'
gem 'rmagick'
gem 'mini_magick' # a smaller implementation of rmagick, required for rqrcode
gem 'rqrcode-rails3'
gem 'strong_parameters'
gem 'libv8', '~> 3.16.14.7'
gem 'rb-readline', '~> 0.5.0'
gem 'stripe', git: 'https://github.com/stripe/stripe-ruby'
gem 'acts_as_paranoid', '~>0.4.0'
gem 'high_voltage'
gem 'omniauth-facebook'
gem 'omniauth-strava'
gem 'omniauth'
gem 'fog'
gem 'dalli'
gem 'draper', require: false
gem 'wkhtmltopdf-binary'
gem 'wicked_pdf'
gem 'eventmachine', '~> 1.0.3'
gem 'sitemap_generator'
gem 'unicorn'
gem 'unicorn-worker-killer'
gem 'rake', '< 11' # Lock rake to remove validation errors

# OAuth provider, Grape, associated parts of API V2
gem 'doorkeeper',   '~> 2.0.1'
gem 'wine_bouncer'
gem 'grape'
gem 'grape-active_model_serializers', git: 'https://github.com/jrhe/grape-active_model_serializers'
gem 'grape-swagger'
gem 'swagger-ui_rails'
gem 'api-pagination'

# Secure things
gem 'rack-throttle'
gem 'secure_headers'

# Frontend
gem 'backbone-on-rails', '~>0.9.10.0' 
gem 'jquery-datatables-rails', '~>3.4.0'
gem 'chartkick' # Display charts
gem 'groupdate'
gem 'bootstrap', '~> 4.0.0.alpha3' # Bootstrap 4 - used for revised stylesheets
gem 'sparkpost' # ruby client for email

# Show performance metrics
gem 'stackprof', require: false
gem 'memory_profiler', require: false
gem 'flamegraph', require: false
gem 'rack-mini-profiler', require: false # If you can't see it you can't make it better


gem 'bundler', '>= 1.8.4' # required for rails-assets.org - JS and CSS assets
source 'https://rails-assets.org' do # JS land is crazy, so lock everything
  gem 'rails-assets-lodash', '~> 4.9.0'
  gem 'rails-assets-tether', '~> 1.1.0'
  gem 'rails-assets-mustache', '~> 2.2.1'
  gem 'rails-assets-jquery.dirtyforms', '~> 2.0.0' # Alert on attempts to leave with dirt on forms
  gem 'rails-assets-selectize', '~> 0.12.1' # Manually configured scss
  gem 'rails-assets-headroom.js', '~> 0.7.0' # Would prefer 0.8 but it isn't on rails-assets yet
  gem 'rails-assets-pikaday', '~> 1.4.0' # Datepicker
  gem 'rails-assets-Stickyfill', '~> 1.1.3' # Affix bike edit menu
  # Sortable breaks assets:precompile, so it's included manually
  # gem 'rails-assets-jquery-sortable', '~> 0.9.12' # Sort photo order
end

group :production do
  gem 'honeybadger', '~> 2.0'
end

group :assets do
  gem 'sass-rails',   '~> 3.2.6'
  gem 'coffee-rails', '~> 3.2.2'
  gem 'therubyracer', '~> 0.12.1' , platforms: :ruby
  gem 'uglifier', '~> 2.7.2'
end

group :development do
  gem 'rerun'
  gem 'guard'
  gem 'guard-rspec', '~> 4.6.4'
  gem 'guard-rubocop'
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
  gem 'factory_girl_rails', '~> 4.2.1'
  gem 'codeclimate-test-reporter', require: nil
  gem 'rspec-sidekiq', '~> 2.2.0'
  gem 'pry'
end