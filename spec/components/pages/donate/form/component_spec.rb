# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::Form::Component, type: :component do
  include_context :active_stripe_prices
  let(:options) { {stripe_prices:, initial_amount:, current_user:, referral_source: "newsletter"} }
  let(:initial_amount) { nil }
  let(:current_user) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "defaults to a monthly Plus membership at the StripePrices' amounts" do
    expect(component).to have_css("#donate-cadence-monthly[checked]")
    expect(component).to have_css("form[action='/membership'] input[name='membership[level]'][value='plus'][checked]")
    expect(component).to have_css("form[action='/membership'] input[name='referral_source'][value='newsletter']", visible: :all)
    expect(component).to have_text("Tiers are $5, $15, and $50 a month")
    expect(component).to have_button("Become a member — $15/month")
    expect(component).to have_css("input[name='payment[amount_cents]'][value='5000'][checked]")
  end

  context "with CAD prices" do
    let(:currency_enum) { "cad" }
    before { stripe_prices.find { it.patron? && it.monthly? }.amount_cents = 4999 }

    it "renders the monthly prices in that currency" do
      expect(component).to have_button("Become a member — $15/month")
      expect(component).to have_text("$49.99")
      expect(component).to have_css("form[action='/membership'] input[name='currency'][value='cad']", visible: :all)
      expect(component).to have_css("input[name='payment[currency]'][value='CAD']", visible: :all)
    end
  end

  context "with a preset initial_amount" do
    let(:initial_amount) { "25" }

    it "selects it as a one-time donation" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_css("input[name='payment[amount_cents]'][value='2500'][checked]")
      expect(component).to have_field("payment[amount]", with: "")
      expect(component).to have_button("Donate $25")
    end
  end

  context "with an initial_amount over what a payment can be" do
    let(:initial_amount) { "1000000" }

    it "ignores it, and caps the other amount at that limit" do
      expect(component).to have_field("payment[amount]", with: "")
      expect(component).to have_css("input[name='payment[amount]'][max='999999.99']")
      expect(component).to have_css("input[name='payment[amount_cents]'][value='5000'][checked]")
    end
  end

  context "with a custom initial_amount" do
    let(:initial_amount) { "500" }

    it "fills the other amount" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_no_css("input[name='payment[amount_cents]'][checked]")
      expect(component).to have_field("payment[amount]", with: "500")
      expect(component).to have_button("Donate $500")
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
      expect(component).to have_button("Donate $50")
    end
  end

  context "with campaign options" do
    let(:options) do
      {stripe_prices:, initial_amount:, current_user:, amounts: [50, 100, 250],
       default_cadence: :one_time}
    end

    it "leads with one-time, at the campaign presets" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component.css("input[name='donate_cadence']").map { it["value"] }).to eq(%w[one-time monthly])
      expect(component.css("input[name='payment[amount_cents]']").map { it["value"] }).to eq(%w[5000 10000 25000])
      expect(component).to have_css("input[name='payment[amount_cents]'][value='10000'][checked][data-default='true']")
      expect(component).to have_button("Donate $100")
    end

    it "puts the one_time_intro outside the form, so Enter in it doesn't submit" do
      component = render_inline(described_class.new(**options)) do |form|
        form.with_one_time_intro(Pages::Donate::TenPercent::Component.new(open: false, currency_symbol: form.currency.symbol))
      end
      expect(component).to have_css("[data-controller~='donate--ten-percent'][data-donate--ten-percent-max-value] [data-ui--collapse-target='content'].tw\\:hidden")
      expect(component).to have_no_css("form [data-controller~='donate--ten-percent']")
      expect(component).to have_no_css("[data-controller~='donate--ten-percent'] input[name]")
    end

    context "with a preset initial_amount" do
      let(:initial_amount) { "250" }

      it "selects it" do
        expect(component).to have_css("input[name='payment[amount_cents]'][value='25000'][checked]")
        expect(component).to have_field("payment[amount]", with: "")
      end
    end

    context "with an initial_amount that was a default preset elsewhere" do
      let(:initial_amount) { "25" }

      it "is an other amount" do
        expect(component).to have_field("payment[amount]", with: "25")
        expect(component).to have_no_css("input[name='payment[amount_cents]'][checked]")
        expect(component).to have_button("Donate $25")
      end
    end
  end
end
