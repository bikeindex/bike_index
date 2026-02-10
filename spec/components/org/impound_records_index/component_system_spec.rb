# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordsIndex::Component, :js, type: :system do
  # This component depends on controller context (SortableTable, @selected_query_items_options,
  # @interpreted_params, @period) that can't be provided in a standalone preview.
  # Rendering is tested in the component_spec instead.
  let(:preview_path) { "/rails/view_components/org/impound_records_index/component/default" }

  it "default preview" do
    skip "Component requires controller context not available in preview"
  end
end
