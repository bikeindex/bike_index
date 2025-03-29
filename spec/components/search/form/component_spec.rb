# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Form::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:interpreted_params) { BikeSearchable.searchable_interpreted_params({}) }
  let(:options) do
    {
      target_search_path: Rails.application.routes.url_helpers.search_index_path,
      interpreted_params:,
      selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
    }
  end

  it "renders" do
    expect(component).to be_present
  end

  describe "component_translation_scope" do
    it "is expected" do
      expect(instance.send(:component_name)).to eq "form"
      expect(instance.send(:component_namespace)).to eq(["search"])
      expect(instance.send(:component_translation_scope)).to eq([:components, "search", "form"])
    end
  end
end
