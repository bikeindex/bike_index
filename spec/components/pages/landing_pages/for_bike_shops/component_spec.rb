# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::ForBikeShops::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {recovery_displays:} }
  let(:recovery_displays) { [] }

  it "renders the signup form and the live stats" do
    Counts.assign_for("total_bikes", 1_234_567)
    Counts.assign_for("recoveries", 18_263)
    Counts.assign_for("recoveries_value", 38_412_345)
    Counts.assign_for("organizations", 1_000)
    expect(component).to have_field("Shop name")
    expect(component).to have_field("Email")
    expect(component).to have_select("Your POS", with_options: ["Lightspeed", "Ascend", "Shopify (coming soon)", "Other / none"])
    expect(component).to have_text("1.2M+")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("1,000+")
    expect(component).to have_css("ol > li", count: 3)
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden", count: 5, visible: :all)
    expect(component).to have_link("See the tools", href: "#free-tools", count: 2)
    expect(component).to have_css("section#free-tools")
    expect(component).to_not have_text("Bikes that came home")
  end

  context "signed in" do
    let(:options) { {recovery_displays:, current_user: FactoryBot.create(:user_confirmed, email: "shop@example.com")} }

    it "uses their email rather than asking for one" do
      expect(component).to have_no_field("Email")
      expect(component).to have_text("You're signed in as shop@example.com")
    end
  end

  it "frames the checker on California" do
    expect(component).to have_css("iframe[src='/ebike-rules/US/CA?manual=1&throttle=0&top_speed=20&watts=750']", visible: :all)
  end

  context "with the visitor's place" do
    let(:options) { {recovery_displays:, checker_place: EbikeRuleServices::Places.find("US-OR")} }

    it "frames the checker on it" do
      expect(component).to have_css("iframe[src^='/ebike-rules/US/OR?']", visible: :all)
    end
  end

  context "with recovery displays" do
    let(:recovery_displays) do
      Array.new(4) { |i| FactoryBot.create(:recovery_display, quote: "Quote #{i}", quote_by: "Owner #{i}", recovered_at: Time.current - i.days) }
    end

    it "renders the recovery stories" do
      expect(component).to have_text("Bikes that came home")
      expect(component).to have_text("Owner 3")
    end
  end
end
