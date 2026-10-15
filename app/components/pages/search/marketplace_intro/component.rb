# frozen_string_literal: true

module Pages
  module Search
    module MarketplaceIntro
      # Both states render, so toggling needs no request - the cookie only picks which shows first
      class Component < ApplicationComponent
        # Shared with app/javascript/controllers/search/marketplace_intro_controller.js, which writes it
        COOKIE_NAME = "marketplace_intro_dismissed"

        def initialize(dismissed:, searched:)
          @collapsed = dismissed || searched
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
