# frozen_string_literal: true

# Disable Rack::Attack throttling by default in test to avoid
# interfering with request specs. Include :rack_attack context
# to test throttling behavior.
Rack::Attack.enabled = false

RSpec.shared_context :rack_attack do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = true
    # Rack::Attack's throttle window is wall-clock-aligned; freeze time so all
    # requests in the example land in one window (a rollover mid-test would
    # otherwise reset the counter and miss the limit).
    freeze_time { example.run }
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end
end
