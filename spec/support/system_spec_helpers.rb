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

  # Resize for this example only -- the browser context is recreated between
  # examples, so the configured viewport comes back on its own.
  def resize_window(width:, height:)
    page.driver.with_playwright_page { |playwright_page| playwright_page.set_viewport_size(width:, height:) }
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

  # Takes the trigger (a page with two of them opens the same modal from either), which names
  # the dialog. The trigger's own command/commandfor is what opens it, so one click is enough
  # and a page that lost them fails here rather than opening once Stimulus catches up.
  def open_modal(trigger)
    element = trigger.is_a?(Capybara::Node::Element) ? trigger : find(trigger)
    retry_on_detach { element.click }
    expect(page).to have_css("##{element["commandfor"]}[open]")
  end

  # Make the page look like a browser from before invoker commands: the controller's detect
  # says no, and the browser's own activation behaviour is cancelled, so only the fallback
  # listeners act. Runs before any script on the page, which is when the detect is read.
  def emulate_browser_without_invoker_commands
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.add_init_script(script: <<~JS)
        delete HTMLButtonElement.prototype.commandForElement
        document.addEventListener("click", (event) => {
          if (event.target.closest("[commandfor]")) event.preventDefault()
        }, true)
      JS
    end
  end

  # Flash messages are fixed position, so an undismissed one intercepts clicks on
  # whatever it overlays. ui--alert wires the close button in `connect` and
  # application.js lazy loads controllers, so a click landing before that module
  # arrives is swallowed. Click again, the way a rider whose click did nothing
  # would, for the whole of `wait` - a click is the only thing that dismisses an
  # alert, so time spent waiting without clicking can never resolve one.
  def dismiss_flash_messages(wait: 10)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait
    loop do
      all("#flash-messages [aria-label='Close']", minimum: 1).each { |close| retry_on_detach { close.click } }
      break if page.has_no_css?("#flash-messages [role='alert']", wait: 1)
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
    end
    expect(page).to have_no_css("#flash-messages [role='alert']", wait: 1)
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
