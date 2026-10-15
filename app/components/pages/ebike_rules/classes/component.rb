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

        def state_class_cards
          state_classes.map do |classification|
            next emoto_card if classification[:not_an_ebike]

            class_card(card: {state: true, either: classification[:either], title: classification[:name], body: classification[:description],
                              assist: classification[:throttle] ? translation(".throttle") : translation(".pedal"),
                              speed: classification[:mph]&.then { translation(".mph", mph: it) }, motor: watts(classification)})
          end
        end

        def watts(classification)
          if classification[:watt_cap]
            translation(".watts_max", watts: classification[:watt_cap])
          elsif classification[:min_watts]
            translation(".watts_min", watts: classification[:min_watts])
          end
        end

        # The three classes, then the e-moto that's none of them, a chosen state's own rules standing in for most states'
        def us_class_cards
          class_3_rules = @state && EbikeRuleServices::StateLaws.class_3_rules(@state[:abbr]).presence
          [1, 2, 3].map { class_card(e_bike_class: it, rules: (class_3_rules if it == 3)) } + [emoto_card]
        end

        def emoto_card
          rules = @state && EbikeRuleServices::StateLaws.emoto_rules(@state[:abbr]).presence
          class_card(card: {n: nil, either: true, title: render(Pages::EbikeRules::UnbrokenHyphens::Component.new(text: translation(".not_an_ebike"))),
                            speed: translation(".emoto_speed"), motor: translation(".emoto_motor"), rules:,
                            body: rules ? translation(".emoto_summary") : translation(".emoto_limits_body")})
        end

        def class_card(**) = Pages::EbikeRules::ClassCard::Component.new(state_name: @state&.dig(:name), **)
      end
    end
  end
end
