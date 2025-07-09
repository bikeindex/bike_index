# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::VehicleThumbnail::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {vehicle:, current_event_record:, skip_cache:} }
  let(:vehicle) { nil }
  let(:current_event_record) { nil }
  let(:skip_cache) { nil }

  it "renders" do
    expect(component).to be_present
  end
end
