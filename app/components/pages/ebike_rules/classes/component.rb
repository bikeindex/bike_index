# frozen_string_literal: true

module Pages
  module EbikeRules
    module Classes
      # The three US classes, or the chosen state's own where its law doesn't use them. A frame, so choosing a state reloads it
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-classes"

        def initialize(state:, additional_classes: nil)
          @state = state
          @additional_classes = additional_classes
        end

        private

        def state_classes
          return @state_classes if defined?(@state_classes)

          @state_classes = @state && EbikeRuleServices::StateLaws.classes(@state[:abbr])
        end

        def cards = state_classes ? state_class_cards : us_class_cards

        def state_class_cards = state_classes.map { class_card(classification: it) }

        # The three classes, then the e-moto that's none of them
        def us_class_cards = [1, 2, 3, nil].map { class_card(e_bike_class: it) }

        def class_card(**) = Pages::EbikeRules::ClassCard::Component.new(state: @state, **)
      end
    end
  end
end
