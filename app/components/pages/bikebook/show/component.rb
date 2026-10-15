# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      # The catalog search and comparison, rendered in the browser from the published catalog.
      # The page is a <template> bikebook--page fills in from the URL and the catalog,
      # and renders again for each pick and history step
      class Component < ApplicationComponent
        # market is the visitor's CF-IPCountry, which Cloudflare sends as XX, or T1 over Tor, when it can't
        # tell; state is theirs in the US
        def initialize(manifest_url:, market:, state:)
          @manifest_url = manifest_url
          @market = %w[XX T1].include?(market) ? "US" : market.presence || "US"
          @jurisdiction = state&.dig(:abbr) || "US"
        end

        private

        # The closed filters' and the open card's, so it's beside whichever shows
        def more_filters = render(UI::Collapse::Component.new(text: translation(".more_filters"), chevron: :trailing,
          color: :link, aria: {controls: "vehicle-filters"}))

        # By the ISO 3166-2 codes the catalog's classifications name their jurisdictions by
        def jurisdiction_names = {"US" => translation(".united_states")}
          .merge(EbikeRuleServices::StateLaws::STATES.to_h { ["US-#{it[:abbr]}", it[:name]] })

        # The US classes, then the states' own, which /ebike-rules shows too; a state without them uses the US ones
        def class_groups
          us = [{id: "class_1", name: translation(".us_class_1")}, {id: "class_2", name: translation(".us_class_2")},
            {id: "class_3", name: translation(".us_class_3")}, EbikeRuleServices::StateLaws::NOT_AN_EBIKE]
          {"US" => us}.merge(EbikeRuleServices::StateLaws.own_classes)
        end
      end
    end
  end
end
