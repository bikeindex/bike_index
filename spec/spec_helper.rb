ENV["BASE_URL"] = "http://test.host" # Assign here because only one .env file
require "sidekiq/testing"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.allow_http_connections_when_no_cassette = true
  config.hook_into :webmock
end

# For codeclimate test coverage. Only enable if the environmental variable is set - i.e. on CI
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails"
end

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../../config/environment", __FILE__)
require "rspec/rails"
# require 'rspec/autorun'
require "database_cleaner"

DatabaseCleaner.strategy = :truncation

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec", "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true
  config.use_transactional_fixtures = true
  config.render_views
  config.infer_spec_type_from_file_location!

  # Add our request spec helpers
  config.include RequestSpecHelpers, type: :request
  config.include RequestSpecHelpers, type: :controller

  config.before :suite do
    DatabaseCleaner.clean
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

def set_current_user(user)
  cookies.signed[:auth] = { secure: true, httponly: true, value: [user.id, user.auth_token] }
end
