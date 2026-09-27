# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Memberships::New::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/memberships/new/component/default" }

  it "updates the prices and labels as the interval and tier change" do
    visit(preview_path)

    expect(page).to have_text("Plus membership, $9.99 a month")
    expect(page).to have_button("Join as Plus — $9.99/mo")
    expect(page).to have_text("$4.99")
    expect(page).to_not have_text("Two months free")
    expect_axe_clean

    find("label", text: "Yearly").click
    expect(page).to have_text("Plus membership, $99.99 a year")
    expect(page).to have_button("Join as Plus — $99.99/yr")
    expect(page).to have_text("$49.99")
    expect(find("#membership-plans")).to_not have_text("$4.99")
    expect(page).to have_text("Two months free", count: 3)

    find("label", text: "Patron badge on your Bike Index profile").click
    expect(page).to have_text("Patron membership, $499.99 a year")
    expect(page).to have_link("Join as Patron — $499.99/yr", href: "#membership-plans")
  end
end
