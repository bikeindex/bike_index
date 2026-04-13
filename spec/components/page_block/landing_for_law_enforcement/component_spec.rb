# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::LandingForLawEnforcement::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "renders" do
    expect(component).to have_css(".le-hero-section")
    expect(component).to have_text("The #1 platform for bike theft recovery")
    expect(component).to have_text("Schedule a Demo")
  end

  it "renders all sections" do
    expect(component).to have_css(".le-municipalities-section")
    expect(component).to have_css(".le-features-section")
    expect(component).to have_css(".le-tools-section")
    expect(component).to have_css(".le-testimonials-section")
    expect(component).to have_css(".le-cta-section")
  end

  it "renders partner logos" do
    expect(component).to have_text("Calgary")
    expect(component).to have_text("Boise City")
    expect(component).to have_text("Los Angeles")
  end

  it "renders testimonials" do
    expect(component).to have_text("Cst. Shawn Davis")
    expect(component).to have_text("Cst. Dan Seibel")
    expect(component).to have_text("Officer Brittany Elenes")
  end
end
