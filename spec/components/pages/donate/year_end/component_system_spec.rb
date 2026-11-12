# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::YearEnd::Component, :js, type: :system do
  before do
    FactoryBot.create(:stripe_price_basic)
    FactoryBot.create(:stripe_price_plus)
    FactoryBot.create(:stripe_price_patron)
    # for the Bike Book card's frame
    serve_bikebook_catalog
  end

  it "fills the gift from a bike's value, and works the 10% button and major gifts" do
    visit "/rails/view_components/pages/donate/year_end/component/default"

    expect(page).to have_button("Donate $100", count: 2, wait: 10)
    expect_axe_clean

    click_on "Work out my 10%"
    wait_for { page.evaluate_script("document.activeElement.placeholder") == "What's your bike worth?" }
    fill_in "What's your bike worth?", with: "2400"
    expect(page).to have_text("10% is $240. We've set that as your gift below.")
    expect(page).to have_field("Other amount", with: "240")
    expect(page).to have_button("Donate $240", count: 2)
    expect(page).to have_no_checked_field("payment[amount_cents]", visible: :all)

    fill_in "What's your bike worth?", with: ""
    expect(page).to have_field("Other amount", with: "")
    expect(page).to have_checked_field("payment[amount_cents]", with: "10000", visible: :all)
    expect(page).to have_button("Donate $100", count: 2)

    # Another amount takes over from the helper, so it stops claiming the gift
    fill_in "What's your bike worth?", with: "2400"
    expect(page).to have_text("10% is $240")
    choose "$50", allow_label_click: true
    expect(page).to have_no_text("10% is $240")
    expect(page).to have_field("What's your bike worth?", with: "")
    fill_in "What's your bike worth?", with: "2400"
    fill_in "Other amount", with: "75"
    expect(page).to have_no_text("10% is $240")
    expect(page).to have_field("What's your bike worth?", with: "")
    # A tenth over the most a payment can be isn't filled in
    fill_in "What's your bike worth?", with: "12000000"
    expect(page).to have_no_text("10% is")
    expect(page).to have_field("Other amount", with: "")
    fill_in "What's your bike worth?", with: ""

    choose "Monthly", allow_label_click: true
    expect(page).to have_button("Become a member — $9.99/month", count: 2)
    click_on "Work out my 10%"
    expect(page).to have_checked_field("donate_cadence", with: "one-time", visible: :all)
    wait_for { page.evaluate_script("document.activeElement.placeholder") == "What's your bike worth?" }

    find("a[data-amount='1000']").click
    expect(page).to have_field("Other amount", with: "1000")
    expect(page).to have_button("Donate $1,000", count: 2)
  end
end
