# frozen_string_literal: true

module Pages
  module EbikeRules
    module LawSummary
      # A law's description, the limits it sets, and its restrictions and sources
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle].freeze

        def initialize(law:)
          @law = law
        end

        private

        # A law outside the US is its own class, which its heading names
        def rule_ids = @law[:metric] ? RULE_IDS - [:classes] : RULE_IDS
      end
    end
  end
end
