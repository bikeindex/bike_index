# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::LandingDonation::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "points the call to action at the plus membership, with a tile for each cadence's amounts" do
    cta = component.at_css("[data-register--landing-donation-target=cta]")
    expect(cta.text.strip).to eq "Become a member — $15/month"
    expect(cta["href"]).to eq "/membership/new?membership_level=plus"

    monthly = component.css("[data-amount-for=monthly]")
    expect(monthly.map { it["data-href"] }).to eq(%w[basic plus patron].map { "/membership/new?membership_level=#{it}" })
    expect(monthly.map { it.key?("checked") }).to eq [false, true, false]

    one_time = component.css("[data-amount-for=one_time]")
    expect(one_time.map { it["data-label"] }).to eq ["Donate $25", "Donate $50", "Donate $100"]
    expect(one_time.map { it["data-href"] }).to eq(%w[25 50 100].map { "/donate?initial_amount=#{it}" })
    expect(component.at_css("[data-controller=register--landing-donation]")["data-register--landing-donation-custom-label-value"])
      .to eq "Donate $%{amount}"
  end
end
