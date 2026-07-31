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

    # Short enough that the body has to scroll rather than grow the dialog
    resize_window(width: 800, height: 400)
    click_button "Open Long"

    expect(page).to have_text("Fingerstache koji mumblecore")
    expect(find('#long-modal button[aria-label="Close"]')).not_to be_obscured
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
