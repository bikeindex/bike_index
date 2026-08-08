# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonGroup::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/button_group/component/" }

  it "renders the chips as links" do
    visit("#{base_path}default")

    expect(page).to have_link "All"
    expect(page).to have_link "Active"
    expect(page).to have_css "a[aria-current='true']", text: "All"
    expect_axe_clean

    visit("#{base_path}with_html_labels")

    # The chip is inline-flex, so each text run/element is a separate flex item —
    # without the wrapping span the whitespace between them gets collapsed
    expect(page).to have_link "only not impounded"
    expect(page).to have_link "only impounded"
  end

  it "renders the chips as buttons, disabled ones included" do
    visit("#{base_path}buttons")

    expect(page).to have_css "button[aria-pressed='true']", text: "Map"
    expect_axe_clean

    visit("#{base_path}with_disabled")

    expect(page).to have_link "All"
    expect(page).to have_button "For sale", disabled: true
    expect_axe_clean
  end
end
