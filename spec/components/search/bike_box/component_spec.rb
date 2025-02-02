# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::BikeBox::Component, type: :component do
  let(:options) { {bike:, current_user:} }
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:bike) { Bike.new }
  let(:current_user) { User.new }

  it "renders" do
    expect(component).to be_present
  end

  describe "component_translation_scope" do
    it "is expected" do
      expect(instance.send(:component_name)).to eq "bike_box"
      expect(instance.send(:component_namespace)).to eq(["search"])
      expect(instance.send(:component_translation_scope)).to eq([:components, "search", "bike_box"])
    end
  end
end
