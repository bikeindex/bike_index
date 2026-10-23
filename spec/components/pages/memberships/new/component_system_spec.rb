# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Memberships::New::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/memberships/new/component/default" }

  it "updates the prices and labels as the interval and tier change" do
    visit(preview_path)

    expect(page).to have_text("Plus membership, $15 a month")
    expect(page).to have_button("Join as Plus — $15/mo")
    within("#membership-plans") { expect(page).to have_text(/\$5\s+\/ month.*\$15\s+\/ month.*\$50\s+\/ month/m) }
    expect(page).to_not have_text("Two months free")
    expect_axe_clean

    find("label", text: "Yearly").click
    expect(page).to have_text("Plus membership, $150 a year")
    expect(page).to have_button("Join as Plus — $150/yr")
    within("#membership-plans") do
      expect(page).to have_text(/\$50\s+\/ year.*\$150\s+\/ year.*\$500\s+\/ year/m)
      expect(page).to_not have_text("/ month")
      expect(page).to have_text("Two months free", count: 3)
    end

    find("label", text: "Patron badge on your Bike Index profile").click
    expect(page).to have_text("Patron membership, $500 a year")
    expect(page).to have_link("Join as Patron — $500/yr", href: "#membership-plans")
  end
end
