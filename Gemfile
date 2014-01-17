source 'http://rubygems.org'

gem 'rails', '3.2.13'

gem 'pg'
gem 'jquery-rails'
gem 'bcrypt-ruby', '~> 3.0.0'
gem 'active_model_serializers'
gem 'aws-sdk', '~> 1.3.4'
gem 'airbrake'
gem 'resque', :require => 'resque/server'
gem 'resque-pool'
gem 'geocoder', "~> 1.1.2"
gem "whenever", require: false
gem "money-rails", "~> 0.5.0"
gem "i18n"
gem "haml-rails", '~> 0.3.5'
gem "journey", "~> 1.0.3"
gem 'rdiscount'
gem 'will_paginate', '~> 3.0'
gem 'pg_search'
gem 'nokogiri', '~> 1.6.0'
gem 'carrierwave', '~> 0.9.0'
gem 'rmagick'
gem "mini_magick" # a smaller implementation of rmagick, required for rqrcode
gem 'rqrcode-rails3'
gem 'strong_parameters'
gem 'libv8', '~> 3.16.14'
gem 'rb-readline', '~> 0.4.2'
gem 'backbone-on-rails', "=0.9.10.0"
gem 'stripe', :git => 'https://github.com/stripe/stripe-ruby'
gem 'jquery-datatables-rails', github: 'rweng/jquery-datatables-rails'
gem "acts_as_paranoid", "~>0.4.0"
gem "high_voltage"
gem 'omniauth-facebook'
gem 'omniauth'
gem "capistrano", "~> 2.15.5"
gem "capistrano-resque", "~> 0.1.0"
gem "fog"
gem 'dalli'
gem 'dumper'
gem 'draper'
# gem 'rack-mini-profiler' # I'm not actually doing anything useful with this and it's annoying.
gem 'dotenv-rails', "~> 0.8", git: "https://github.com/bkeepers/dotenv"
gem 'wkhtmltopdf-binary'
gem 'wicked_pdf'

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'therubyracer', :platforms => :ruby
  gem 'uglifier', '>= 1.0.3'
  gem "select2-rails"
end

group :develop do
  gem 'growl'
  gem 'brakeman'
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-livereload'
  gem 'bullet'
end

group :develop, :test do
  gem 'rb-fsevent', '~> 0.9.1'
  gem 'rspec-rails'
  gem 'foreman'
  gem 'database_cleaner'
end

group :test do
  gem 'factory_girl_rails'
  gem 'simplecov', require: false
  gem 'resque_spec'
  gem 'shoulda-matchers'
  gem 'pry'
end
