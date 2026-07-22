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

  # Navigate back/forward and wait for Turbo Drive to finish the restoration
  # visit before returning. Search pages reload their results turbo-frame from
  # the URL independently of -- and faster than -- the page render, so tbody
  # counts and the address bar can settle while the form still shows the previous
  # query. Turbo fires exactly one turbo:load per restoration visit (after the
  # popstate the search--form controller reconciles the fields on); register a
  # one-shot listener, navigate, then wait for it so the whole restoration has
  # landed before we read or fill the form.
  def go_back_and_wait(wait: 10)
    page.execute_script(<<~JS)
      document.documentElement.removeAttribute("data-test-turbo-loaded")
      document.addEventListener("turbo:load", () => document.documentElement.setAttribute("data-test-turbo-loaded", ""), {once: true})
    JS
    page.go_back
    expect(page).to have_css("html[data-test-turbo-loaded]", wait:, visible: :all)
  end

  # capybara-playwright wraps click/find so a mid-action "Element is not attached
  # to the DOM" (Turbo re-rendering the field) becomes a StaleReferenceError that
  # Capybara auto-retries -- but its `set` path (fill_in) only rescues timeouts,
  # so the raw Playwright::Error escapes. Re-find and re-fill on detach, which is
  # what Capybara does for the wrapped actions.
  def fill_in(*args, **options, &block)
    attempts = 0
    begin
      super
    rescue Playwright::Error => e
      raise unless e.message.include?("not attached to the DOM") && (attempts += 1) <= 3
      sleep 0.1
      retry
    end
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
