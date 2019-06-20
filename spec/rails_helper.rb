# simplecov must be required before anything else
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start("rails") do
    add_filter "/spec/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Decorators", "app/decorators"
    add_group "Serializers", "app/serializers"
    add_group "Services", "app/services"
    add_group "Uploaders", "app/uploaders"
    add_group "Libraries", "lib"
  end

  Rails.application.eager_load! if defined?(Rails)
end

require "spec_helper"

# Assign here because only one .env file
ENV["BASE_URL"] = "http://test.host"
ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../config/environment", __FILE__)

require "rspec/rails"

require "database_cleaner"
require "rspec-sidekiq"
require "vcr"

ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec", "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.render_views

  # Add our request/controller spec helpers
  config.include RequestSpecHelpers, type: :request
  config.include ControllerSpecHelpers, type: :controller
  config.include JsonHelpers, type: :controller
  config.include JsonHelpers, type: :request
  config.include StripeHelpers, type: :request
  config.include StripeHelpers, type: :controller
  config.include StripeHelpers, type: :service
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.allow_http_connections_when_no_cassette = true
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :host, :path],
  }

  config.before_record do |i|
    i.response.headers.delete("Set-Cookie")
    i.request.headers.delete("Authorization")
    i.request.headers.delete("X-Stripe-Client-User-Agent")
  end
end

RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end

# DB Cleaner metadata tags
# ========================
#
# Use the following RSpec metadata tags to tweak how the database is reset
# between tests.
#
# * `strategy: :transaction` (default)
#
# Fastest. Performs queries in a transaction and rolls back at the end of the
# test. A sensible default. The tag can be omitted.
#
# * `strategy: :deletion`
#
# Slower, but comparable in speed to :transaction for small data sets.
# Useful for testing `after_commit` callbacks.
# Does not re-create tables or indexes.
#
# * `strategy: :truncation`
#
# Slowest. Fixed-time regardless of the amount of data (hence cost-effective
# only for large or complicated data setups). Runtime grows with the number of
# tables, indexes, complexity of the db overall.
#
# * `:context_state`
#
# To skip example-wise cleaning (e.g., to share large setup between examples).
# Use sparingly.
#
# ```
# before(:all) { ... }
#
# describe "test 1", :context_state do ...
#
# describe "test 2", :context_state do ...
# ```
#
# * `:js`
#
# For acceptance / system tests (Capybara/Cucumber/Rails 5 system tests) with a
# JS driver. Enables the truncation strategy, which is slowest but most stable.
#
class DirtyDatabaseError < RuntimeError
  def initialize(meta)
    super "#{meta[:full_description]}\n\t#{meta[:location]}"
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before(:all, :context_state) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.before(:each) do |example|
    next if example.metadata[:context_state]

    strategy =
      example.metadata[:strategy] ||
      (example.metadata[:js] ? :truncation : :transaction)

    DatabaseCleaner.strategy = strategy
    DatabaseCleaner.start
  end

  config.after(:each) do |example|
    next if example.metadata[:context_state]

    DatabaseCleaner.clean

    # For debugging:
    # if ModelName.count > 0
    #   raise DirtyDatabaseError.new(example.metadata)
    # end
  end

  config.after(:all, :context_state) do
    DatabaseCleaner.clean
  end
end
