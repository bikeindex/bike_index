# frozen_string_literal: true

module Org
  module SearchResults
    module MultiResults
      class Component < ApplicationComponent
        def initialize(organization:, query:, chip_id:, pagy:, search_kind: "serials",
          bikes: nil, close_serials: nil, sort_state: ComponentStates::SortState.new)
          @organization = organization
          @sort_state = sort_state
          @query = query
          @chip_id = chip_id
          @pagy = pagy
          @search_kind = search_kind
          @bikes = bikes
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
          return @displayed_bikes if defined?(@displayed_bikes)

          @displayed_bikes = bikes_array.presence || @close_serials&.to_a
        end

        def close_serials_only?
          bikes_array.empty? && displayed_bikes.present?
        end

        # Load @bikes once; every emptiness check then stays in-memory rather than re-querying
        def bikes_array
          @bikes_array ||= @bikes.to_a
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
end
