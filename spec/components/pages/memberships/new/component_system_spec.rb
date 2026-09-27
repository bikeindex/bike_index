# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Memberships::New::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/pages/memberships/new/component/default" }

  it "updates the prices and labels as the interval and tier change" do
    visit(preview_path)

    expect(page).to have_text("Plus membership, $15 a month")
    expect(page).to have_button("Join as Plus — $15/mo")
    within("#membership-plans") { expect(page).to have_text(/\$5\s+\/ month.*\$15\s+\/ month.*\$50\s+\/ month/m) }
    expect_axe_clean

    find("label", text: "Yearly").click
    expect(page).to have_text("Plus membership, $180 a year")
    expect(page).to have_button("Join as Plus — $180/yr")
    within("#membership-plans") do
      expect(page).to have_text(/\$60\s+\/ year.*\$180\s+\/ year.*\$600\s+\/ year/m)
      expect(page).to_not have_text("/ month")
    end

    find("label", text: "Patron badge on your Bike Index profile").click
    expect(page).to have_text("Patron membership, $600 a year")
    expect(page).to have_link("Join as Patron — $600/yr", href: "#membership-plans")
  end
end
