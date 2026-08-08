# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Modal::Component, :js, type: :system do
  # Both paths end in the same place, so the examples differ only in how they get there.
  # wait: the held back controller writes the param once it arrives, not on the click.
  def expect_settings_modal_opens_and_closes(wait: Capybara.default_max_wait_time)
    click_button "Open Settings"
    expect(page).to have_css("dialog#settings-modal[open]")
    expect(page).to have_text("Modal body content")
    expect(page).to have_current_path(/modal_settings-modal=1/, url: true, wait:)

    find('button[aria-label="Close"]').click
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_no_current_path(/modal_settings-modal/, url: true)
  end

  # Make the page look like a browser from before invoker commands: the controller's detect
  # says no, and the browser's own activation behaviour is cancelled, so only the fallback
  # listeners act. Runs before any script on the page, which is when the detect is read.
  # It cancels for every [commandfor], so don't reach for it on a submit button.
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

  it "opens and closes modal" do
    visit("/rails/view_components/ui/modal/component/default")

    expect_axe_clean

    click_button "Open Settings"

    expect(page).to have_text("Modal body content")
    expect_axe_clean

    find('button[aria-label="Close"]').click

    expect(page).not_to have_css("dialog[open]")

    # Short enough that the body has to scroll rather than grow the dialog
    resize_window(width: 800, height: 400)
    open_modal(find_button("Open Long"))

    expect(page).to have_text("Fingerstache koji mumblecore")
    expect(find('#long-modal button[aria-label="Close"]')).not_to be_obscured
  end

  # The point of the trigger's command/commandfor: opening doesn't wait on Stimulus, which
  # lazy loads and so may not have arrived when the click lands.
  it "opens from the trigger with the controller held back, and picks the state up on connect" do
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route("**/ui/modal_controller*.js", ->(route, _request) {
        sleep 1
        route.continue
      })
    end
    visit("/rails/view_components/ui/modal/component/default")

    # It opens on the click, and the controller adopts it on arrival - so the param, which
    # only the controller writes, is what proves it caught up with a dialog it never opened
    expect_settings_modal_opens_and_closes(wait: 10)
  end

  # Nothing else reaches the fallback: the browser these run in takes the native path every
  # time, so without this the listeners the older half of the world depends on go unexercised.
  it "opens and closes through the controller's listeners without invoker commands" do
    emulate_browser_without_invoker_commands
    visit("/rails/view_components/ui/modal/component/default")

    expect_settings_modal_opens_and_closes
  end

  it "opens a server-opened modal on load, without adding the param" do
    visit("/rails/view_components/ui/modal/component/open_on_connect")

    expect(page).to have_css("dialog[open]")
    expect(page).to have_text("Server-opened modal body")
    # Not persisted — whether it comes back on reload is the server's call
    expect(page).not_to have_current_path(/modal_open-on-connect-modal/, url: true)
    expect_axe_clean

    find('button[aria-label="Close"]').click
    expect(page).not_to have_css("dialog[open]")
  end
end
