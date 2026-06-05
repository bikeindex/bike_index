# frozen_string_literal: true

require "capybara/rails"
require "capybara/rspec"
require "capybara-lockstep"

Capybara.register_driver :chrome_headless do |app|
  # unhandled_prompt_behavior: "ignore" keeps capybara-lockstep from stalling on
  # a JS dialog (alert/confirm/prompt) that a spec hasn't explicitly accepted.
  options = Selenium::WebDriver::Chrome::Options.new(unhandled_prompt_behavior: "ignore")
  options.add_argument("--headless")
  options.add_argument("--window-size=1920,1080")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.configure do |config|
  config.default_driver = :chrome_headless
  config.javascript_driver = :chrome_headless
  # Make CSS transitions/animations instant in the browser. capybara-lockstep
  # syncs JS/AJAX but not CSS transitions, so an element animating into place
  # (e.g. a collapse('show') panel that pushes a table down) can move while
  # Capybara dispatches a click at its pre-animation coords, and the click
  # misses. Instant transitions remove that whole class of flake.
  config.disable_animation = true
end

# Pin Capybara's app server to a predictable host:port. Defaults to
# DEV_PORT + 2000 so it doesn't collide with a developer's running
# `bin/dev` (which binds DEV_PORT itself); override with CAPYBARA_PORT
# when the test infrastructure needs to know the port up front (e.g. CI's
# `assets:precompile` step needs a matching BASE_URL so any ERB-baked
# asset URL resolves to the same host the browser will hit).
CAPYBARA_PORT = (ENV["CAPYBARA_PORT"] || ENV.fetch("DEV_PORT", "3042").to_i + 2000).to_i
Capybara.server_host = "localhost"
Capybara.server_port = CAPYBARA_PORT
Capybara.app_host = "http://#{Capybara.server_host}:#{CAPYBARA_PORT}"
Capybara.always_include_port = true

# Keep BASE_URL aligned with Capybara's server for `:js` specs so any
# `*_url` helper rendered during the example -- or ERB-interpolated asset
# (`<%= ENV['BASE_URL'] %>...`) that gets sprockets-compiled on demand --
# targets the Capybara server.
RSpec.configure do |config|
  config.around(:each, :js) do |example|
    original_base_url = ENV["BASE_URL"]
    ENV["BASE_URL"] = "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    example.run
  ensure
    ENV["BASE_URL"] = original_base_url
  end
end
