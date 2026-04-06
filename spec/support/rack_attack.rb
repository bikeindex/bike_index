# frozen_string_literal: true

# Disable Rack::Attack throttling by default in test to avoid
# interfering with request specs. Include :rack_attack context
# to test throttling behavior.
Rack::Attack.enabled = false

RSpec.shared_context :rack_attack do
  around do |example|
    Rack::Attack.enabled = true
    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store.clear
  end
end
