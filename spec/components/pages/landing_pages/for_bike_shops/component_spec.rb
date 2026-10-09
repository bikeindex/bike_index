# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::ForBikeShops::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) do
    {total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000,
     recovery_displays:, feedback: Feedback.new, signed_up:}
  end
  let(:recovery_displays) { [] }
  let(:signed_up) { false }

  it "renders the signup form and the live stats" do
    expect(component).to have_css("h1", text: "Send every bike home with a sidekick.")
    expect(component).to have_css("form#new_feedback input[name='feedback[feedback_type]'][value='lead_for_bike_shop']", visible: :all)
    expect(component).to have_field("Shop name")
    expect(component).to have_css("input#feedback_name[maxlength='255']")
    expect(component).to have_select("Your POS", with_options: ["Lightspeed", "Ascend", "Shopify (coming soon)", "Other / none"])
    expect(component).to have_text("1,234,567")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("1,000+")
    expect(component).to have_css("ol > li", count: 3)
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden", count: 5, visible: :all)
    expect(component).to have_link("Sign up your shop", href: "#shop-signup")
    expect(component).to_not have_text("Bikes that came home")
  end

  context "signed up" do
    let(:signed_up) { true }

    it "renders the success state instead of the form" do
      expect(component).to have_text("You're in.")
      expect(component).to have_text("We'll email you about connecting your POS.")
      expect(component).to_not have_css("form#new_feedback")
    end
  end

  context "with recovery displays" do
    let(:recovery_displays) do
      Array.new(4) { |i| FactoryBot.create(:recovery_display, quote: "Quote #{i}", quote_by: "Owner #{i}", recovered_at: Time.current - i.days) }
    end

    it "renders the first three quotes" do
      expect(component).to have_text("Bikes that came home")
      expect(component).to have_css("blockquote", count: 3)
      expect(component).to have_text("Owner 2")
      expect(component).to_not have_text("Quote 3")
    end
  end
end
