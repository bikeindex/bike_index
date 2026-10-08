# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Rendered whole, so search engines read the collapsed rules too
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle].freeze

        private

        # A republished vocabulary has a new file name, and a law's dated rules move on each day
        def cache_key = [self.class.cache_digest, EbikeRuleServices::BikebookCatalog.manifest&.dig("vocabulary"), Time.zone.today]

        def laws = @laws ||= EbikeRuleServices::StateLaws.laws

        def states = EbikeRuleServices::StateLaws::STATES.map { it.merge(law: laws[it[:abbr]]) }
      end
    end
  end
end
