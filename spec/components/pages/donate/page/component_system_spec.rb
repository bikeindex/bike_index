# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::Page::Component, :js, type: :system do
  it "keeps the submit labels on the selected amount" do
    visit "/rails/view_components/pages/donate/page/component/default"

    expect(page).to have_button("Become a member — $15/month", count: 2, wait: 10)
    expect_axe_clean

    choose "Patron membership", allow_label_click: true
    expect(page).to have_button("Become a member — $50/month", count: 2)

    choose "One-time", allow_label_click: true
    expect(page).to have_button("Donate $50", count: 2)
    expect(page).to have_no_button("Become a member — $50/month")

    fill_in "Other amount", with: "37.5"
    expect(page).to have_button("Donate $37.50", count: 2)
    expect(page).to have_no_checked_field("payment[amount_cents]", visible: :all)

    choose "$100", allow_label_click: true
    expect(page).to have_button("Donate $100", count: 2)
    expect(page).to have_field("Other amount", with: "")

    choose "Monthly", allow_label_click: true
    find("a[data-amount='1000']").click
    expect(page).to have_button("Donate $1,000", count: 2)
    expect(page).to have_field("Other amount", with: "1000")
    expect(page).to have_css("a[data-amount='1000'][data-active='true']")
  end
end
