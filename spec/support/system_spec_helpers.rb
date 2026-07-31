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

  # Turn on touch emulation, which is what makes `(pointer: coarse)` match, so
  # touch-only styles render (Playwright's emulate_media doesn't cover pointer).
  # The override lives as long as the CDP session, so unlike reset_browser_history
  # this one is left attached -- the browser context is recreated between
  # examples, which is teardown enough.
  def emulate_touch_device
    page.driver.with_playwright_page do |playwright_page|
      session = playwright_page.context.new_cdp_session(playwright_page)
      session.send_message("Emulation.setTouchEmulationEnabled", params: {enabled: true, maxTouchPoints: 1})
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

  # search--form#handlePopstate reconciles these to the address bar on a
  # back/forward; the results frame reloads separately and faster.
  RESTORED_FILTER_FIELDS = %w[search_email serial search_notes].freeze

  # Navigate back, then wait for the filters to settle to the address bar so
  # callers don't read or fill against the restoration preview.
  def go_back_and_wait(wait: 10)
    page.go_back
    restored = Rack::Utils.parse_query(URI.parse(page.current_url).query)
    RESTORED_FILTER_FIELDS.each do |name|
      next unless page.has_selector?("input[name='#{name}']", wait: 0)
      expect(page).to have_field(name, with: restored[name].to_s, wait:)
    end
  end

  # capybara-playwright wraps click/find so a mid-action "Element is not attached
  # to the DOM" (Turbo re-rendering the field) becomes a StaleReferenceError that
  # Capybara auto-retries -- but its `set` path (fill_in) only rescues timeouts,
  # so the raw Playwright::Error escapes. Re-find and re-fill on detach, which is
  # what Capybara does for the wrapped actions.
  def fill_in(*args, **options, &block)
    retry_on_detach { super }
  end

  # Click an async hotwire_combobox option, re-finding it if a later async
  # response re-renders the listbox and detaches the node between find and click.
  def click_combobox_option(text)
    retry_on_detach { find(".hw-combobox__option", text:, match: :first).click }
  end

  # ui--modal wires its trigger in `connect`, and application.js lazy loads controllers -
  # so a click landing before that module arrives is swallowed, leaving Capybara waiting
  # on a dialog that will never open. Click again, the way a rider whose click did
  # nothing would, until the dialog reports itself open. Takes the trigger (a page
  # with two of them opens the same modal from either), which names the dialog.
  def open_modal(trigger, attempts: 5)
    element = trigger.is_a?(Capybara::Node::Element) ? trigger : find(trigger)
    modal_id = element["data-open-modal"]
    attempts.times do
      retry_on_detach { element.click }
      return if page.has_css?("##{modal_id}[open]", wait: 1)
    end
    raise "##{modal_id} never opened after #{attempts} clicks"
  end

  private

  # Retry a Playwright action when the node detaches mid-action -- the raw
  # Playwright::Error that Capybara's own retry doesn't rescue on this driver.
  def retry_on_detach(attempts: 3)
    tries = 0
    begin
      yield
    rescue Playwright::Error => e
      raise unless e.message.include?("not attached to the DOM") && (tries += 1) <= attempts
      sleep 0.1
      retry
    end
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
