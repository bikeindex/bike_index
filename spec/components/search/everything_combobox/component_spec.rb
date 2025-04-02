# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::EverythingCombobox::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:interpreted_params) { BikeSearchable.searchable_interpreted_params({}) }
  let(:options) do
    {
      query: interpreted_params[:query],
      selected_query_items_options: BikeSearchable.selected_query_items_options(interpreted_params)
    }
  end

  it "renders" do
    expect(component).to be_present
  end
end
