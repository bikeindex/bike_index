# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::LandingForSchools::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "renders" do
    expect(component).to have_css(".le-hero-section")
    expect(component).to have_text("The #1 platform for campus bike management")
    expect(component).to have_text("Schedule a Demo")
  end

  it "renders all sections" do
    expect(component).to have_css(".le-municipalities-section")
    expect(component).to have_css(".le-features-section")
    expect(component).to have_css(".le-tools-section")
    expect(component).to have_css(".le-testimonials-section")
    expect(component).to have_css(".le-cta-section")
  end

  it "renders university partners" do
    expect(component).to have_text("CU Boulder")
    expect(component).to have_text("Penn State")
    expect(component).to have_text("UCLA")
  end

  it "renders testimonials" do
    expect(component).to have_text("Ted Sweeney")
    expect(component).to have_text("Cecily Zhu")
    expect(component).to have_text("Thomas Worth")
  end
end
