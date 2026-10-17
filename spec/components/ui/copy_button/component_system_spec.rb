# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::CopyButton::Component, :js, type: :system do
  it "copies its value, swapping to a check and back" do
    visit "/rails/view_components/ui/copy_button/component/default"
    expect_axe_clean
    wait_for_stimulus("ui--copy-button")

    button = find_button("Copy ID")
    button.click

    expect(button).to have_css("svg.tw\\:text-green-600", visible: :visible)
    expect(page.evaluate_script("navigator.clipboard.readText()")).to eq "r/21J-HW"
    expect(button).to have_css("svg.tw\\:text-green-600", visible: :hidden, wait: 3)
  end

  it "shows its label and value in a tooltip, and still copies" do
    visit "/rails/view_components/ui/copy_button/component/tooltip"
    wait_for_stimulus("ui--copy-button")

    button = find("button[aria-label='Copy ID (m/trek/2025/fetch)']")
    button.hover
    expect(page).to have_css("[role='tooltip']", exact_text: "Copy ID (m/trek/2025/fetch)", visible: true)
    expect(page).to have_css("[role='tooltip'] code", exact_text: "m/trek/2025/fetch", visible: true)
    button.click
    expect(page.evaluate_script("navigator.clipboard.readText()")).to eq "m/trek/2025/fetch"
  end
end
