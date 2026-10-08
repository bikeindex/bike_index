# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Rendered whole, so search engines read the collapsed rules too
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle].freeze

        private

        # A republished vocabulary has a new file name
        def cache_key = [self.class.cache_digest, ::EbikeRules::BikebookCatalog.manifest&.dig("vocabulary")]

        def laws = @laws ||= ::EbikeRules::StateLaws.laws

        def states = ::EbikeRules::StateLaws::STATES.map { it.merge(law: laws[it[:abbr]]) }
      end
    end
  end
end
