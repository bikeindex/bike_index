# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Alerts::FlashMessage::Component, :js, type: :system do
  it "dismisses every message, so dismiss_flash_messages clears the whole region" do
    visit "/rails/view_components/ui/alerts/flash_message/component/multiple"

    expect(page).to have_content "Saved successfully"
    expect(page).to have_content "But there was a warning"
    expect_axe_clean

    dismiss_flash_messages

    expect(page).to have_no_content "Saved successfully"
    expect(page).to have_no_content "But there was a warning"
  end
end
