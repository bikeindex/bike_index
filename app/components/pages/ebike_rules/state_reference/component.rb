# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Rendered whole, so search engines read the collapsed rules too
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle].freeze

        def initialize
          @laws = ::EbikeRules::StateLaws.laws || {}
        end

        private

        def states = ::EbikeRules::StateLaws::STATES.map { it.merge(law: @laws[it[:abbr]]) }
      end
    end
  end
end
