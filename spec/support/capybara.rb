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

# The same browser with scripting turned off, for specs about what a rider without
# JavaScript gets. rack_test applies no stylesheets and runs no HTML5 constraint
# validation, so a form a real browser refuses to submit passes there.
Capybara.register_driver :playwright_no_js do |app|
  Capybara::Playwright::Driver.new(app,
    browser_type: :chromium,
    headless: true,
    javaScriptEnabled: false,
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
# during the example resolve to it. default_url_options is read off BASE_URL once at
# boot, so it takes the same treatment -- otherwise a helper called outside a request
# (a service's, rather than a view's) renders a host the browser can't reach, and the
# link it's on can't be clicked.
RSpec.configure do |config|
  config.around(:each, :js) do |example|
    original_base_url = ENV["BASE_URL"]
    url_options = Rails.application.routes.default_url_options
    original_host = url_options[:host]
    ENV["BASE_URL"] = "http://#{Capybara.current_session.server.host}:#{Capybara.current_session.server.port}"
    url_options[:host] = ENV["BASE_URL"]
    example.run
  ensure
    ENV["BASE_URL"] = original_base_url
    url_options[:host] = original_host
  end

  # Any playwright-driven example, scripting or not - rack_test has nothing to block.
  # An example picks its driver with `driver:` metadata rather than `driven_by`, which
  # runs too late for this to reach the session it chose
  config.before(:each, type: :system) do
    driver = Capybara.current_session.driver
    next unless driver.respond_to?(:with_playwright_page)

    driver.with_playwright_page do |playwright_page|
      BLOCKED_EXTERNAL_HOSTS.each do |host|
        playwright_page.route("https://#{host}/**", ->(route, _request) { route.abort })
      end
    end
  end
end
