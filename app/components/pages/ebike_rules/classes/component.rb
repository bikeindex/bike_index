# frozen_string_literal: true

module Pages
  module EbikeRules
    module Classes
      # The three US classes, the chosen state's own where its law doesn't use them, each followed by the state's e-bike and
      # non-e-bike rules, one open at a time, or a place outside the US's laws and its other classes. A frame, so choosing a place reloads it
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-classes"
        NON_E_BIKE_RULES_ID = "non-e-bike-rules"

        def self.classification_value(classification) = classification[:id].split("/").last

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

          @outside_us = @place && EbikeRuleServices::StateLaws.places[@place[:code]]
        end

        def state_law
          return @state_law if defined?(@state_law)

          @state_law = us_state? && EbikeRuleServices::StateLaws.find(@place[:abbr])
        end

        def non_e_bike_classifications
          @non_e_bike_classifications ||= us_state? ? EbikeRuleServices::StateLaws.non_e_bike_classifications(@place[:abbr]) : []
        end

        def us_state? = @place && EbikeRuleServices::Places.us?(@place)

        # The id's last segment: moped, of evc/us/ca/moped
        def classification_value(classification) = self.class.classification_value(classification)

        def cards = @cards ||= class_cards

        def class_cards
          if outside_us
            outside_us[:classes].map { class_card(classification: it) }
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
