# frozen_string_literal: true

module Pages
  module Search
    module MarketplaceIntro
      # Both states render, so toggling needs no request - a dismissal or a search starts it collapsed
      class Component < ApplicationComponent
        # Shared with app/javascript/controllers/search/marketplace_intro_controller.js, which writes it
        COOKIE_NAME = "marketplace_intro_dismissed"
        # Any other query param - utm_source, fbclid - isn't a search
        SEARCH_PARAMS = (Bike.permitted_search_params.flat_map { it.try(:keys) || it } +
          %i[marketplace_scope price_min_amount price_max_amount page]).map(&:to_s).freeze

        def initialize(dismissed:, query_parameters:)
          @collapsed = dismissed || query_parameters.slice(*SEARCH_PARAMS).compact_blank.present?
        end

        private

        def trust_chips
          [translation(".registered_bikes_only"), translation(".checked_for_theft"),
            translation(".ownership_transfers"), translation(".bike_index_members")]
        end
      end
    end
  end
end
