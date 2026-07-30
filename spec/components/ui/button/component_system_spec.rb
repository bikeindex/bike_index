# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Button::Component, :js, type: :system do
  let(:spinner) { "[data-ui--button--submit-spinner-target='spinner']" }

  it "reveals the spinner once the form submits, and not before" do
    visit "/rails/view_components/ui/button/component/in_form"

    expect(page).to have_button("Next", wait: 10)
    expect(page).to have_no_css(spinner)
    expect_axe_clean

    # Native validation rejects the empty email, so the form never submits
    click_button "Next"

    expect(page).to have_button("Next")
    expect(page).to have_no_css(spinner)

    # Not an RFC 2606 domain: the field holds the form on one, and this submit has to land
    fill_in "Email", with: "user@bikeindex.org"
    click_button "Next"

    expect(page).to have_css(spinner)
    expect(page).to have_button("Next", disabled: true)
    expect_axe_clean
  end
end
