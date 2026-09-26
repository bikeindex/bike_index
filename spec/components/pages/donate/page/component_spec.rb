# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::Page::Component, type: :component do
  let(:options) { {recovery_displays: [], monthly_prices:, initial_amount:, current_user:, referral_source: "newsletter"} }
  let(:monthly_prices) { [FactoryBot.create(:stripe_price_basic), FactoryBot.create(:stripe_price_plus), FactoryBot.create(:stripe_price_patron)] }
  let(:initial_amount) { nil }
  let(:current_user) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "defaults to a monthly Plus membership at the StripePrices' amounts" do
    expect(component).to have_css("#donate-cadence-monthly[checked]")
    expect(component).to have_css("form[action='/membership'] input[name='membership[level]'][value='plus'][checked]")
    expect(component).to have_css("form[action='/membership'] input[name='referral_source'][value='newsletter']", visible: :all)
    expect(component).to have_text("Tiers are $4.99, $9.99, and $49.99 a month")
    expect(component).to have_button("Become a member — $9.99/month", count: 2)
    expect(component).to have_css("input[name='payment[amount_cents]'][value='5000'][checked]")
    expect(component).to have_css("img[src='#{described_class::WALL_PHOTOS.first}']", count: 1)
  end

  context "without a monthly price" do
    let(:monthly_prices) { [] }

    it "offers one-time only" do
      expect(component).to have_no_css("input[name='donate_cadence']")
      expect(component).to have_no_css("form[action='/membership']")
      expect(component).to have_button("Donate $50", count: 2)
    end
  end

  context "with a preset initial_amount" do
    let(:initial_amount) { "25" }

    it "selects it as a one-time donation" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_css("input[name='payment[amount_cents]'][value='2500'][checked]")
      expect(component).to have_field("payment[amount]", with: "")
      expect(component).to have_button("Donate $25", count: 2)
    end
  end

  context "with a custom initial_amount" do
    let(:initial_amount) { "500" }

    it "fills the other amount" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_no_css("input[name='payment[amount_cents]'][checked]")
      expect(component).to have_field("payment[amount]", with: "500")
      expect(component).to have_button("Donate $500", count: 2)
    end
  end

  context "with a member" do
    let(:current_user) { FactoryBot.create(:user) }
    before { FactoryBot.create(:membership, user: current_user) }

    it "links to their membership instead of offering monthly" do
      expect(component).to have_no_css("input[name='donate_cadence']")
      expect(component).to have_no_css("form[action='/membership']")
      expect(component).to have_link("Manage your membership", href: "/membership/edit")
      expect(component).to have_css("input[name='payment[email]'][value='#{current_user.email}']", visible: :all)
      expect(component).to have_button("Donate $50", count: 2)
    end
  end
end
