# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::LocationAddressFields::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {form_builder:, current_country_id:, default_region_record_id:, default_region_string:} }
  let(:form_builder) { nil }
  let(:current_country_id) { nil }
  let(:default_region_record_id) { nil }
  let(:default_region_string) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
