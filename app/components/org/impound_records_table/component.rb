# frozen_string_literal: true

module Org
  module ImpoundRecordsTable
    class Component < ApplicationComponent
      include Binxtils::SortableHelper

      def initialize(impound_records:, current_organization:, render_sortable: false, render_resolved_at: false, skip_status: false, skip_bike: false, skip_location: nil, skip_multiselect: false, multiselect_visible: false)
        @impound_records = impound_records
        @current_organization = current_organization
        @render_sortable = render_sortable
        @render_resolved_at = render_resolved_at
        @skip_status = skip_status
        @skip_bike = skip_bike
        @skip_location = skip_location.nil? ? !current_organization.enabled?("impound_bikes_locations") : skip_location
        @skip_multiselect = skip_multiselect
        @multiselect_visible = multiselect_visible
      end

      def multiselect_cell_classes
        ["multi-update-cell table-cell-check", ("tw:hidden" unless @multiselect_visible)].compact.join(" ")
      end
    end
  end
end
