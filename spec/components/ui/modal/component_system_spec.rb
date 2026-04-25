# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Modal::Component, :js, type: :system do
  it "opens and closes modal" do
    visit("/rails/view_components/ui/modal/component/default")

    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

    click_button "Open Settings"

    expect(page).to have_text("Modal body content")
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

    find('button[aria-label="Close"]').click

    expect(page).not_to have_css("dialog[open]")
  end
end
