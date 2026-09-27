# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Memberships::New::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) do
    {currency:, level:, bikes_count: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345,
     organizations_count: 1_000, recovery_displays:, referral_source: "donate"}
  end
  let(:currency) { Currency.default }
  let(:level) { nil }
  let(:recovery_displays) { [] }

  it "renders the plans with plus selected" do
    expect(component).to have_css("h1", text: "Keep Bike Index free for every rider")
    expect(component).to have_text("1M+")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("Plans from $5 a month")
    expect(component).to have_checked_field("membership_level_plus", visible: :all)
    expect(component).to have_checked_field("membership_set_interval_monthly", visible: :all)
    expect(component).to have_css("input[name='referral_source'][value='donate']", visible: :all)
    expect(component).to have_css("[data-memberships--new-target='summary']", text: "Plus membership, $15 a month")
    expect(component).to have_css("[data-memberships--new-target='join']", text: "Join as Plus — $15/mo", count: 2)
    expect(component).to have_text("$150")
    expect(component).to have_css("details[name='membership-faq']", count: 5)
    expect(component).to have_css("details[open]", count: 1)
    expect(component).to have_link("Or make a one-time donation", href: "/donate")
    expect(component).to_not have_link("Read more recovery stories")

    labels = JSON.parse(component.css("#membership_level_patron").first["data-labels"])
    expect(labels).to eq({"monthly" => {"summary" => "Patron membership, $50 a month", "join" => "Join as Patron — $50/mo"},
                          "yearly" => {"summary" => "Patron membership, $500 a year", "join" => "Join as Patron — $500/yr"}})
  end

  context "with a passed level" do
    let(:level) { "patron" }

    it "selects it" do
      expect(component).to have_checked_field("membership_level_patron", visible: :all)
      expect(component).to have_css("[data-memberships--new-target='summary']", text: "Patron membership, $50 a month")
    end
  end

  context "with an unknown level" do
    let(:level) { "gold" }

    it "falls back to plus" do
      expect(component).to have_checked_field("membership_level_plus", visible: :all)
    end
  end

  context "with CAD" do
    let(:currency) { Currency.friendly_find("cad") }

    it "renders CAD prices" do
      expect(component).to have_css("input[name='currency'][value='cad']", visible: :all)
      expect(component).to have_css("[data-memberships--new-target='summary']", text: /Plus membership, \D*15 a month/)
    end
  end

  context "with more recovery displays than it shows" do
    let(:recovery_displays) do
      Array.new(5) { |i| FactoryBot.create(:recovery_display_with_photo, quote: "Quote #{i}", quote_by: "Owner #{i}") }
    end

    it "renders the first four" do
      expect(component).to have_link("Read more recovery stories", href: "/recovery_stories")
      expect(component).to have_css("ul > li blockquote", count: 4)
      expect(component).to_not have_text("Quote 4")
    end
  end
end
