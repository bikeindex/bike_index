# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::Ascend::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {} }

  it "walks through the three setup steps" do
    expect(component).to have_css("ol > li", count: 3)
    expect(component).to have_link("Start setup", href: "#setup")
    expect(component).to have_css("section#setup")
    expect(component).to have_link("Create shop account", href: "/organizations/new")
    expect(component).to have_link("Open Ascend guide", href: described_class::ASCEND_GUIDE_URL, target: "_blank")
    expect(component).to have_link("Email us", href: "mailto:bikeshops@bikeindex.org?subject=Ascend%20setup")
    expect(component).to have_link("Privacy policy", href: "/privacy")
    expect(component).to have_link("POS integration security FAQ", href: "/info/security-faq-pos-integrations")
    expect(component).to have_link("Lightspeed POS integration", href: "/lightspeed")
    expect(component).to_not have_text("Your shop is on Bike Index")
  end

  context "with a shop" do
    let(:options) { {has_shop: true} }

    it "marks the account step done" do
      expect(component).to have_css("ol > li", count: 3)
      expect(component).to have_text("Your shop is on Bike Index")
      expect(component).to_not have_link("Create shop account")
      expect(component).to have_link("Open Ascend guide")
    end
  end
end
