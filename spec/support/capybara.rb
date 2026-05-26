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

# Pin Capybara's app server to a predictable host:port derived from DEV_PORT
# so it doesn't collide with a developer's running `bin/dev` (which binds
# DEV_PORT itself). Without a pinned port, Capybara picks a random one and
# any compiled asset that bakes `<%= ENV['BASE_URL'] %>` into its content
# (e.g. `revised/components/manufacturers_select.coffee.erb`'s autocomplete
# URL) points at a host the browser can't reach.
Capybara.server_host = "localhost"
Capybara.server_port = ENV.fetch("DEV_PORT", "3042").to_i + 2000
Capybara.app_host = "http://#{Capybara.server_host}:#{Capybara.server_port}"
Capybara.always_include_port = true

# Align BASE_URL with Capybara's port so any ERB-interpolated asset URL
# (`<%= ENV['BASE_URL'] %>...`) that gets dynamically compiled during the
# test run targets the Capybara server. Overrides the "http://test.host"
# default set in rails_helper.
ENV["BASE_URL"] = Capybara.app_host

# Keep BASE_URL aligned with Capybara's server for `:js` specs so any
# `*_url` helper rendered during the example matches the page origin.
RSpec.configure do |config|
  config.around(:each, :js) do |example|
    original_base_url = ENV["BASE_URL"]
    ENV["BASE_URL"] = "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    example.run
  ensure
    ENV["BASE_URL"] = original_base_url
  end
end
