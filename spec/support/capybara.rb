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

  config.before(:each, :js) do
    Capybara.current_session.driver.with_playwright_page do |playwright_page|
      BLOCKED_EXTERNAL_HOSTS.each do |host|
        playwright_page.route("https://#{host}/**", ->(route, _request) { route.abort })
      end
    end
  end
end
