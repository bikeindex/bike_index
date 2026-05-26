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

# Bind Capybara's app server to the host:port that bin/env already publishes
# as `BASE_URL` (`http://localhost:#{DEV_PORT}`). Without this, Capybara picks
# a random port and any compiled asset that bakes `<%= ENV['BASE_URL'] %>`
# into its content (e.g. `revised/components/manufacturers_select.coffee.erb`'s
# autocomplete URL) points at a host the browser can't reach. Pinning the
# server here keeps the page-origin and any baked absolute URLs aligned.
Capybara.server_host = "localhost"
Capybara.server_port = ENV.fetch("DEV_PORT", "3042").to_i
Capybara.app_host = "http://#{Capybara.server_host}:#{Capybara.server_port}"
Capybara.always_include_port = true

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
