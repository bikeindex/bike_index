# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Parts::LandingDonation::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "renders a form per cadence, whose buttons work without the controller" do
    monthly, one_time = component.css("form")
    expect(monthly["action"]).to eq "/membership/new"
    expect(monthly["method"]).to eq "get"
    expect(monthly.at_css("button[type=submit]").text.strip).to eq "Become a member"
    levels = monthly.css("[name=membership_level]")
    expect(levels.map { it["value"] }).to eq %w[basic plus patron]
    expect(levels.map { it.key?("checked") }).to eq [false, true, false]
    expect(levels.map { it["data-label"] }).to eq(["$5", "$15", "$50"].map { "Become a member — #{it}/month" })
    expect(monthly.text).to include("Cancel a monthly gift any time.", "What membership includes")

    expect(one_time["action"]).to eq "/donate"
    expect(one_time.at_css("button[type=submit]").text.strip).to eq "Donate"
    amounts = one_time.css("[name=initial_amount]")
    expect(amounts.map { it["value"] }).to eq %w[25 50 100]
    expect(amounts.map { it.key?("checked") }).to eq [false, true, false]
    expect(amounts.map { it["data-label"] }).to eq ["Donate $25", "Donate $50", "Donate $100"]
    expect(one_time.text).to_not include("Cancel a monthly gift")
    # Only the controller submits it, so it's hidden until one connects
    expect(one_time.at_css("input[type=number]")["name"]).to be_nil
    expect(one_time.at_css("[data-register--landing-donation-target=customField]")["class"]).to include("tw:hidden")

    # Browsers restoring a back navigation's picks would leave the buttons naming others
    expect(component.css("input[type=radio]").map { it["autocomplete"] }.uniq).to eq ["off"]
  end
end
