# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, :js, type: :system do
  # Skip page-level rules that come from the component preview layout, not from the components
  let(:axe_skipped_rules) { [:"html-has-lang", :"landmark-one-main", :"page-has-heading-one", :region] }

  it "toggles menu on click" do
    visit("/rails/view_components/ui/dropdown/component/default")

    expect(page).to be_axe_clean.skipping(*axe_skipped_rules)
    expect(page).not_to have_css("[data-dropdown-target='menu']:not(.tw\\:hidden)")

    click_button "actions"

    expect(page).to have_text("Profile")
    expect(page).to have_text("Settings")
  end
end
