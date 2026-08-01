# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Modal::Component, :js, type: :system do
  it "opens and closes modal" do
    visit("/rails/view_components/ui/modal/component/default")

    expect_axe_clean

    click_button "Open Settings"

    expect(page).to have_text("Modal body content")
    expect_axe_clean

    find('button[aria-label="Close"]').click

    expect(page).not_to have_css("dialog[open]")
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

    click_button "Open Settings"
    expect(page).to have_css("dialog#settings-modal[open]")
    expect(page).to have_text("Modal body content")

    # Once it does arrive it adopts the open dialog, so a reload still restores it
    expect(page).to have_current_path(/modal_settings-modal=1/, url: true, wait: 10)

    find('button[aria-label="Close"]').click
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_no_current_path(/modal_settings-modal/, url: true)
  end

  # Nothing else reaches the fallback: the browser these run in takes the native path every
  # time, so without this the listeners the older half of the world depends on go unexercised.
  it "opens and closes through the controller's listeners without invoker commands" do
    emulate_browser_without_invoker_commands
    visit("/rails/view_components/ui/modal/component/default")

    click_button "Open Settings"
    expect(page).to have_css("dialog#settings-modal[open]")
    expect(page).to have_text("Modal body content")
    expect(page).to have_current_path(/modal_settings-modal=1/, url: true)

    find('button[aria-label="Close"]').click
    expect(page).to have_no_css("dialog[open]")
    expect(page).to have_no_current_path(/modal_settings-modal/, url: true)
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
