# frozen_string_literal: true

module Org
  module MultiSearchResults
    class Component < ApplicationComponent
      include Binxtils::SortableHelper

      def initialize(organization:, query:, chip_id:, pagy:, search_kind: "serials",
        bikes: nil, interpreted_params: nil, per_page: nil, close_serials: nil)
        @organization = organization
        @query = query
        @chip_id = chip_id
        @pagy = pagy
        @search_kind = search_kind
        @bikes = bikes
        @interpreted_params = interpreted_params
        @per_page = per_page
        @close_serials = close_serials
      end

      private

      def sticker_search?
        @search_kind == "stickers"
      end

      def result_index
        @chip_id&.delete_prefix("chip_")
      end

      # Fall back to close serials (near Levenshtein matches) when nothing matched exactly
      def displayed_bikes
        @bikes.presence || @close_serials
      end

      def close_serials_only?
        @bikes.blank? && @close_serials.present?
      end

      # Drives the JS filter that drops empty results; close serials must keep it alive
      def displayed_result_count
        displayed_bikes&.size || 0
      end

      def show_view_all?
        @pagy.count > @pagy.limit
      end

      def view_all_path
        if sticker_search?
          organization_stickers_path(organization_id: @organization.to_param, query: @query)
        else
          organization_registrations_path(organization_id: @organization.to_param, search_serial: @query)
        end
      end
    end
  end
end
