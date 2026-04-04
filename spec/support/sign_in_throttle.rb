# frozen_string_literal: true

# Disabled by default in test to avoid interfering with request specs.
# Include :sign_in_throttle context to test throttling behavior.
SignInThrottle.enabled = false

RSpec.shared_context :sign_in_throttle do
  around do |example|
    SignInThrottle.enabled = true
    example.run
  ensure
    SignInThrottle.enabled = false
  end
end
