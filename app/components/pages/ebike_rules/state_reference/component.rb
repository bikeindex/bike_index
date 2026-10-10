# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Rendered whole, so search engines read the collapsed rules too
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle].freeze
        # Open, a state's row becomes a card across the whole grid
        STATE_CLASSES = "tw:border-b tw:border-gray-200 tw:dark:border-gray-700 tw:has-[[aria-expanded=true]]:col-span-full " \
          "tw:has-[[aria-expanded=true]]:my-4 tw:has-[[aria-expanded=true]]:rounded-lg tw:has-[[aria-expanded=true]]:border " \
          "tw:has-[[aria-expanded=true]]:bg-white " \
          "tw:has-[[aria-expanded=true]]:shadow-[0_10px_30px_rgba(44,62,80,.12)] tw:dark:has-[[aria-expanded=true]]:bg-gray-800"

        private

        # A republished vocabulary has a new file name, and a law's dated rules move on each day
        def cache_key = [self.class.cache_digest, Integrations::Bikebook::Catalog.manifest&.dig("vocabulary"), Time.zone.today]

        def laws = @laws ||= EbikeRuleServices::StateLaws.laws

        def own_classes = @own_classes ||= EbikeRuleServices::StateLaws.own_classes

        def states = EbikeRuleServices::StateLaws::STATES.map { it.merge(law: laws[it[:abbr]], own_classes: own_classes.key?(it[:abbr])) }
      end
    end
  end
end
