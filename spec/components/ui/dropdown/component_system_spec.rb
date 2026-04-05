# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, :js, type: :system do
  it "toggles menu on click" do
    visit("/rails/view_components/ui/dropdown/component/default")

    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
    expect(page).not_to have_css("[data-dropdown-target='menu']:not(.tw\\:hidden)")

    click_button "menu"

    expect(page).to have_text("Profile")
    expect(page).to have_text("Settings")
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
  end
end
