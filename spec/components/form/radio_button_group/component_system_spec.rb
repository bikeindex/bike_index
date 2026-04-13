# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::RadioButtonGroup::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/form/radio_button_group/component/" }

  it "renders default preview" do
    visit("#{base_path}default")

    expect(page).to have_css "label", count: 3
    expect(page).to have_content "All"
    expect(page).to have_content "Active"
    expect(page).to have_content "Inactive"
    expect(page).to have_checked_field("search_status", with: "", visible: :hidden)
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
  end

  context "with_selection" do
    it "renders with pre-selected value" do
      visit("#{base_path}with_selection")

      expect(page).to have_checked_field("search_status", with: "active", visible: :hidden)
    end
  end

  context "clicking a radio button" do
    it "selects the clicked option" do
      visit("#{base_path}default")

      find("label", text: "Active").click
      expect(page).to have_checked_field("search_status", with: "active", visible: :hidden)

      find("label", text: "Inactive").click
      expect(page).to have_checked_field("search_status", with: "inactive", visible: :hidden)
    end
  end
end
