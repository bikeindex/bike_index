# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::FormOrganized::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {target_search_path:, target_frame:, interpreted_params:, skip_serial_field:, result_view:} }
  let(:target_search_path) { nil }
  let(:target_frame) { nil }
  let(:interpreted_params) { nil }
  let(:skip_serial_field) { nil }
  let(:result_view) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
