# frozen_string_literal: true

require "capybara/rails"
require "capybara/rspec"
require "capybara-playwright-driver"

Capybara.register_driver :playwright do |app|
  # Playwright drives the `playwright` npm package (see package.json) and
  # auto-waits for elements/navigation, so no separate lockstep sync is needed.
  Capybara::Playwright::Driver.new(app,
    browser_type: :chromium,
    headless: true,
    viewport: {width: 1920, height: 1080})
end

Capybara.configure do |config|
  config.default_driver = :playwright
  config.javascript_driver = :playwright
end

# Each parallel worker needs its own port - a pinned one leaves all but the first
# with EADDRINUSE.
Capybara.server_host = "localhost"
Capybara.always_include_port = true

# The application layout pulls Google Fonts and analytics from external hosts
# (app/views/layouts/application.html.erb and shared/_analytics.html). Playwright's
# `visit` waits for the page `load` event, which stalls for the full navigation
# timeout when those hosts are unreachable from CI -- a flaky `visit` failure on
# any page. Abort the requests so `load` fires on the app's own assets. Spec-level
# routes (e.g. Mapbox stubs) register later and take precedence.
BLOCKED_EXTERNAL_HOSTS = %w[
  fonts.googleapis.com
  fonts.gstatic.com
  www.googletagmanager.com
  www.google-analytics.com
].freeze

# Point BASE_URL at Capybara's server for `:js` specs, so `*_url` helpers rendered
# during the example resolve to it.
RSpec.configure do |config|
  config.around(:each, :js) do |example|
    original_base_url = ENV["BASE_URL"]
    ENV["BASE_URL"] = "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    example.run
  ensure
    ENV["BASE_URL"] = original_base_url
  end

  config.before(:each, :js) do
    Capybara.current_session.driver.with_playwright_page do |playwright_page|
      BLOCKED_EXTERNAL_HOSTS.each do |host|
        playwright_page.route("https://#{host}/**", ->(route, _request) { route.abort })
      end
    end
  end
end
