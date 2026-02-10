# frozen_string_literal: true

module Org::ImpoundRecordsIndex
  class ComponentPreview < ApplicationComponentPreview
    # NOTE: This component depends on controller context (SortableTable, @selected_query_items_options,
    # @interpreted_params, @period) that can't be provided in a preview. See component_spec for tests.
    def default
      organization = Organization.first || FactoryBot.create(:organization)
      pagy = Pagy::Offset.new(count: 0, limit: 25, page: 1)
      render(Org::ImpoundRecordsIndex::Component.new(
        pagy:,
        impound_records: ImpoundRecord.none,
        search_status: "current",
        search_unregisteredness: "all",
        time_range: (Time.current - 1.year)..Time.current,
        available_statuses: %w[current all],
        current_organization: organization
      ))
    end
  end
end
