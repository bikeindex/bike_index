# frozen_string_literal: true

module Org
  module ImpoundRecordsTable
    class Component < ApplicationComponent
      include Binxtils::SortableHelper

      def initialize(impound_records:, current_organization:, render_sortable: false, render_resolved_at: false, skip_status: false, skip_bike: false, skip_location: nil, skip_multiselect: false)
        @impound_records = impound_records
        @current_organization = current_organization
        @render_sortable = render_sortable
        @render_resolved_at = render_resolved_at
        @skip_status = skip_status
        @skip_bike = skip_bike
        @skip_location = skip_location.nil? ? !current_organization.enabled?("impound_bikes_locations") : skip_location
        @skip_multiselect = skip_multiselect
      end

      def multiselect_cell_classes(impound_record)
        ["multiselect-cell table-cell-check collapse",
          *impound_record.update_multi_kinds.map { |k| "canupdate-#{k}" }].join(" ")
      end
    end
  end
end
