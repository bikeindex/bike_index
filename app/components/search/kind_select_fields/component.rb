# frozen_string_literal: true

module Search
  module KindSelectFields
    class Component < ApplicationComponent
      DEFAULT_DISTANCE = 100
      MAX_DISTANCE = 2_000 # IDK, seems reasonable
      MARKETPLACE_SCOPES = %w[for_sale_proximity for_sale].freeze
      # TODO: add Found, Found in search area
      STOLENNESS_SCOPES = %w[proximity stolen non all for_sale].freeze

      def initialize(kind_scope:, location: nil, distance: nil)
        @kind_scope = kind_scope
        @is_marketplace = MARKETPLACE_SCOPES.include?(@kind_scope)

        @distance = GeocodeHelper.permitted_distance(distance, default_distance:)
        @location = location
      end

      private

      def default_distance
        @is_marketplace ? Search::MarketplaceController::DEFAULT_DISTANCE : GeocodeHelper::DEFAULT_DISTANCE
      end

      def api_count_url
        @is_marketplace ? "/search/marketplace/counts" : "/api/v3/search/count"
      end

      def location_initially_shown?
        %w[proximity for_sale_proximity].include?(@kind_scope)
      end

      def option_kind
        @is_marketplace ? :marketplace_scope : :stolenness
      end

      def radio_entries
        radio_options.map { {value: it, label: option_label(it)} }
      end

      # Registration search sends for_sale off to the marketplace search instead of
      # scoping in place, so there it's a link chip rather than a radio
      def radio_options
        @is_marketplace ? MARKETPLACE_SCOPES : STOLENNESS_SCOPES - ["for_sale"]
      end

      def marketplace_link_entry
        {label: option_label("for_sale"), href: search_marketplace_path, id: "kindSelectForSaleLink",
         data: {basepath: search_marketplace_path}}
      end

      def option_label(opt)
        safe_join([translation(".#{option_kind}_#{opt}"),
          tag.span(class: "twless-strong", data: {count_target: opt})], " ")
      end
    end
  end
end
