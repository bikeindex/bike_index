# frozen_string_literal: true

module Pages
  module EbikeRules
    module Classes
      # The three US classes, the chosen state's own where its law doesn't use them, or a place outside the US's laws
      # and its other classes. A frame, so choosing a place reloads it
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-classes"

        def initialize(place:, additional_classes: nil)
          @place = place
          @additional_classes = additional_classes
        end

        private

        def state_classes
          return @state_classes if defined?(@state_classes)

          @state_classes = @place && EbikeRuleServices::StateLaws.classes(@place[:abbr])
        end

        def outside_us
          return @outside_us if defined?(@outside_us)

          @outside_us = @place && !EbikeRuleServices::Places.us?(@place) && EbikeRuleServices::StateLaws.places[@place[:code]]
        end

        def cards = @cards ||= class_cards

        def class_cards
          if outside_us
            outside_us[:classes].map { class_card(classification: EbikeRuleServices::StateLaws.classification(it)) }
          elsif state_classes
            state_classes.map { class_card(classification: it) }
          else
            us_class_cards
          end
        end

        # The three classes, then the e-moto that's none of them
        def us_class_cards = [1, 2, 3, nil].map { class_card(e_bike_class: it) }

        def class_card(**) = Pages::EbikeRules::ClassCard::Component.new(place: @place, **)
      end
    end
  end
end
