# frozen_string_literal: true

module Pages
  module Search
    module MarketplaceIntro
      # Dismissible intro above the marketplace search. Both states render, so the
      # toggle needs no request - the cookie only picks which one shows first.
      # A search collapses it too, without the cookie: it's in the way of the results,
      # not dismissed
      class Component < ApplicationComponent
        # Shared with app/javascript/controllers/search/marketplace_intro_controller.js, which writes it
        COOKIE_NAME = "marketplace_intro_dismissed"

        def initialize(dismissed:, searched:)
          @collapsed = dismissed || searched
        end

        private

        def trust_chips
          [translation(".registered_bikes_only"), translation(".checked_for_theft"),
            translation(".ownership_transfers"), translation(".verified_sellers")]
        end
      end
    end
  end
end
