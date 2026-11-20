# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::Lightspeed::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {} }

  it "walks through the two setup steps" do
    expect(component).to have_css("ol > li", count: 2)
    expect(component).to have_link("Start setup", href: "#setup")
    expect(component).to have_css("section#setup")
    expect(component).to have_text("Log in to your shop's Bike Index dashboard")
    expect(component).to have_link("Log in", href: "/session/new")
    expect(component).to have_link("Create one for free", href: "/users/new?return_to=%2Forganizations%2Fnew")
    expect(component).to have_link("Connect Lightspeed", href: "https://posintegration.bikeindex.org/sorrysaccount")
    expect(component).to have_link("Privacy policy", href: "/privacy")
    expect(component).to have_link("POS integration security FAQ", href: "/info/security-faq-pos-integrations")
    expect(component).to have_link("Lightspeed Retail for bike shops", href: described_class::LIGHTSPEED_URL)
    expect(component).to have_link("Ascend POS integration", href: "/ascend")
    expect(component).to have_link("gavin@bikeindex.org", href: "mailto:gavin@bikeindex.org", count: 2)
    expect(component).to have_text("Seth Herr")
    expect(component).to_not have_text("This step is done.")
  end

  context "with a shop" do
    let(:options) { {has_shop: true} }

    it "marks the log in step done" do
      expect(component).to have_css("ol > li", count: 2)
      expect(component).to have_text("You're logged in to your shop's dashboard")
      expect(component).to have_text("This step is done.")
      expect(component).to_not have_link("Log in")
      expect(component).to_not have_text("Don't have a shop account yet?")
      expect(component).to have_link("Connect Lightspeed")
    end
  end
end
