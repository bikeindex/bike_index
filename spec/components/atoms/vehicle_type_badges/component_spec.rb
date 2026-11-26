# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::VehicleTypeBadges::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }
  let(:bike) { Bike.new(cycle_type: :bike, propulsion_type:) }
  let(:propulsion_type) { "foot-pedal" }

  it "renders the type alone" do
    expect(component).to have_text("Bike")
    expect(component).to have_no_text("⚡")
  end

  context "an e-bike" do
    let(:propulsion_type) { "pedal-assist" }

    it "leads with the e-vehicle badge" do
      expect(component).to have_text("⚡")
      expect(component).to have_text("E-vehicle")
    end
  end
end
