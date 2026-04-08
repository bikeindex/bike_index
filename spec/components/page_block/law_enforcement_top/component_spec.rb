# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::LawEnforcementTop::Component, type: :component do
  let(:instance) { described_class.new(recoveries_value:, recoveries:, organization_count:) }
  let(:component) { render_inline(instance) }
  let(:recoveries_value) { 11_000_000 }
  let(:recoveries) { 12_345 }
  let(:organization_count) { 500 }

  it "renders with passed-in stats" do
    expect(component).to have_text("$11M")
    expect(component).to have_text("12,345+")
    expect(component).to have_text("500+")
  end

  it "renders hero section" do
    expect(component).to have_css(".le-hero-section")
    expect(component).to have_text("The #1 platform for bike theft recovery")
    expect(component).to have_text("Schedule a Demo")
  end

  it "renders partner logos" do
    expect(component).to have_css(".le-partner-logo", minimum: 9)
    expect(component).to have_css("img[alt='Calgary']")
    expect(component).to have_text("Los Angeles")
  end

  it "renders three features" do
    expect(component).to have_css(".le-feature-block", count: 3)
    expect(component).to have_text("Law Enforcement Dashboard")
    expect(component).to have_text("Investigative Resources")
    expect(component).to have_text("Community Recovery")
  end

  it "renders tabbed widget" do
    expect(component).to have_css(".le-tab-button", count: 2)
    expect(component).to have_css(".le-tab-panel", count: 2)
  end

  it "renders tools section" do
    expect(component).to have_css(".le-tool-item", count: 10)
  end

  it "renders testimonials" do
    expect(component).to have_css(".le-testimonial", count: 3)
  end

  it "renders CTA section" do
    expect(component).to have_css(".le-cta-section")
    expect(component).to have_text("Ready to recover more bikes")
  end

  it "renders stimulus controllers" do
    expect(component).to have_css("[data-controller='law-enforcement--bike-tiles']")
    expect(component).to have_css("[data-controller='law-enforcement--tabs']")
    expect(component).to have_css("[data-controller='law-enforcement--testimonials']")
  end

  it "passes bike tile images to stimulus controller" do
    tiles_div = component.css("[data-controller='law-enforcement--bike-tiles']").first
    images = JSON.parse(tiles_div["data-law-enforcement--bike-tiles-images-value"])
    expect(images.length).to eq 17
    expect(images.first).to include("bike-entry_0000")
  end
end
