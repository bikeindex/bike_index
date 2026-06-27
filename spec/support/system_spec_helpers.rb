# frozen_string_literal: true

# Helpers for :js system specs that need browser behavior Capybara doesn't
# abstract across drivers. Implemented for the Playwright driver via its raw
# page (see spec/support/capybara.rb).
module SystemSpecHelpers
  # Clear the back/forward stack so go_back/go_forward operate on this example's
  # own short stack -- Capybara never resets history between examples, so it
  # accumulates across the suite.
  def reset_browser_history
    page.driver.with_playwright_page do |playwright_page|
      session = playwright_page.context.new_cdp_session(playwright_page)
      session.send_message("Page.resetNavigationHistory")
      session.detach
    end
  end

  def browser_cookie_value(name)
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.cookies.find { |cookie| cookie["name"] == name }&.fetch("value")
    end
  end

  # Type into a field with real keystrokes. Capybara's `set`/`fill_in` go through
  # Playwright's fill, which dispatches only an `input` event; JS that opens on
  # keydown (e.g. hotwire_combobox's async dropdown) needs real key events.
  def type_into(locator, text)
    field = locator.is_a?(Capybara::Node::Element) ? locator : find(locator)
    field.set("")
    field.send_keys(text)
    field
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
