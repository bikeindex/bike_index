# frozen_string_literal: true

require "capybara/rails"
require "capybara/rspec"

Capybara.register_driver :chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--window-size=1920,1080")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.configure do |config|
  config.default_driver = :chrome_headless
  config.javascript_driver = :chrome_headless
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
