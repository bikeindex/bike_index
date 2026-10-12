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
end
