require "spec_helper"

# Assign here because only one .env file
ENV["BASE_URL"] = "http://test.host"
ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../config/environment", __FILE__)

require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec", "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Add our request spec helpers
  config.include RequestSpecHelpers, type: :request
  config.include RequestSpecHelpers, type: :controller
end

def set_current_user(user)
  cookies.signed[:auth] =
    { secure: true, httponly: true, value: [user.id, user.auth_token] }
end
