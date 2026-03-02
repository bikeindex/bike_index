# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BikeSearch::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {organization:, bikes:, pagy:, interpreted_params:, sortable_search_params:, per_page:, params:, search_stickers:, search_address:, search_status:, search_query_present:, time_range:, stolenness:, bike_sticker:, model_audit:, only_show_bikes:} }
  let(:organization) { nil }
  let(:bikes) { nil }
  let(:pagy) { nil }
  let(:interpreted_params) { nil }
  let(:sortable_search_params) { nil }
  let(:per_page) { nil }
  let(:params) { nil }
  let(:search_stickers) { nil }
  let(:search_address) { nil }
  let(:search_status) { nil }
  let(:search_query_present) { nil }
  let(:time_range) { nil }
  let(:stolenness) { nil }
  let(:bike_sticker) { nil }
  let(:model_audit) { nil }
  let(:only_show_bikes) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
