# simplecov must be required before anything else
if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov_json_formatter"
  SimpleCov.start("rails") do
    add_filter "/spec/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Serializers", "app/serializers"
    add_group "Services", "app/services"
    add_group "Uploaders", "app/uploaders"
  end

  Rails.application.eager_load! if defined?(Rails)
end

# Assign here because only one .env file
ENV["BASE_URL"] = "http://test.host"
ENV["RAILS_ENV"] ||= "test"
ENV["SKIP_MEMOIZE_MANUFACTURER_OTHER"] = "true"

require "spec_helper"
require File.expand_path("../../config/environment", __FILE__)
require "rspec/rails"

# Include capybara for view component system specs
require "capybara/rails"
require "capybara/rspec"
Capybara.register_driver :chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--window-size=1920,1080")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end
# Configure Capybara
Capybara.configure do |config|
  config.default_driver = :chrome_headless
  config.javascript_driver = :chrome_headless
end

require "view_component/test_helpers"
require "view_component/system_test_helpers"

ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.render_views

  # include translation / localization methods
  config.include AbstractController::Translation

  # Add our request/controller spec helpers
  config.include RequestSpecHelpers, type: :request
  config.include ControllerSpecHelpers, type: :controller
  config.include JsonHelpers, type: :controller
  config.include JsonHelpers, type: :request
  config.include StripeHelpers, type: :request
  config.include StripeHelpers, type: :controller
  config.include StripeHelpers, type: :service

  # Set default geocoder location
  config.include_context :geocoder_default_location

  # View components
  config.include ViewComponent::TestHelpers, type: :component
  config.include ViewComponent::SystemTestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
  config.before(:each, :js, type: :system) { driven_by(:selenium_chrome_headless) }
end

require "vcr"
VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.allow_http_connections_when_no_cassette = false
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :host, :path]
  }
  config.ignore_hosts("127.0.0.1", "0.0.0.0") # for capybara selenium

  %w[GOOGLE_GEOCODER MAILCHIMP_KEY FACEBOOK_AD_TOKEN CLOUDFLARE_TOKEN MAXMIND_KEY].each do |key|
    config.filter_sensitive_data("<#{key}>") { ENV[key] }
  end

  config.before_record do |i|
    i.response.headers.delete("Set-Cookie")
    i.request.headers.delete("Authorization")
    i.request.headers.delete("X-Stripe-Client-User-Agent")
  end
end

# retry flaky specs on CI
if ENV["RETRY_FLAKY"]
  require "rspec/retry"

  RSpec.configure do |config|
    # configure retry
    config.verbose_retry = true # show retry status in spec process

    config.around(:each) do |ex|
      if ex.metadata[:flaky]
        ex.run_with_retry retry: 2
      else
        ex.run
      end
    end
  end
end

require "rspec-sidekiq"
RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end

require "database_cleaner"
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
    super("#{meta[:full_description]}\n\t#{meta[:location]}")
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

# CarrierWave Settings
# ====================
RSpec.configure do |config|
  config.before(:all) do
    FileUtils.mkdir_p(ApplicationUploader.cache_dir)
  end

  config.after(:all) do
    FileUtils.rm_rf(ApplicationUploader.cache_dir)
    FileUtils.mkdir_p(ApplicationUploader.cache_dir)
  end
end

CarrierWave.configure do |config|
  config.cache_dir = Rails.root.join("tmp", "cache", "carrierwave#{ENV["TEST_ENV_NUMBER"]}")
  config.enable_processing = false
end
