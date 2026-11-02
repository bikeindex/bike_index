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

  it "stacks every segment of a toggle once they don't all fit on a line" do
    visit("#{base_path}toggle")
    lines = -> { all("button").map { it.evaluate_script("this.getBoundingClientRect().top") }.uniq.count }
    settled_on = ->(count) { page.document.synchronize { raise Capybara::ExpectationNotMet unless lines.call == count } }

    settled_on.call(1)
    # room for two on a line, where they'd otherwise stay
    resize_window(width: 230, height: 600)
    settled_on.call(3)
    # their labels at one left edge, though they're different widths
    expect(all("button span").map { it.evaluate_script("this.getBoundingClientRect().left") }.uniq.count).to eq 1
    resize_window(width: 1024, height: 600)
    settled_on.call(1)
  end
end
