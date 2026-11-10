# frozen_string_literal: true

module Pages
  module EbikeRules
    module LawSummary
      # A law's description, the limits it sets, and its restrictions and sources. `titled`, under its name, which
      # stands in for the classes it recognizes: it's a class of its own
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle].freeze

        def initialize(law:, titled: false)
          @law = law
          @titled = titled
        end

        private

        def rule_ids = @titled ? RULE_IDS - [:classes] : RULE_IDS
      end
    end
  end
end
