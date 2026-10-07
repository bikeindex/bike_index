# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Rendered whole, so search engines read the collapsed rules too
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle age helmet paths label].freeze

        private

        def states = ::EbikeRules::StateLaws::STATES.map { it.merge(law: ::EbikeRules::StateLaws.find(it[:abbr])) }

        def on_file_count = ::EbikeRules::StateLaws::LAWS.count

        def rule_value(law, id)
          return translation(".watts_html", watts: number_display(law[:watt_cap])) if id == :power

          law[:text][id]
        end
      end
    end
  end
end
