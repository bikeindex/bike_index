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

            {state: true, either: classification[:either], title: classification[:name], body: classification[:description],
             assist: classification[:throttle] ? translation(".throttle") : translation(".pedal"),
             speed: classification[:mph]&.then { translation(".mph", mph: it) }, motor: watts(classification)}
          end
        end

        # An either card's limits are alternatives, each but the last followed by an "or" centered in the gap after its row
        def row_value(value, or_after:)
          tag.span(class: "tw:whitespace-nowrap") do
            next value unless or_after

            safe_join([value, " ", tag.span(translation(".or"), class: "tw:absolute tw:inset-y-0 tw:left-full tw:flex tw:w-8 " \
              "tw:items-center tw:justify-center tw:text-[11.5px] tw:opacity-65")])
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
          motor_cap = translation(".motor_cap")
          class_3_rules = @state && EbikeRuleServices::StateLaws.class_3_rules(@state[:abbr]).presence
          [
            {n: 1, title: translation(".class_n", n: 1), tag: translation(".class_1_tag"), assist: translation(".pedal"),
             speed: translation(".mph", mph: 20), motor: motor_cap, body: translation(".class_1_body")},
            {n: 2, title: translation(".class_n", n: 2), tag: translation(".class_2_tag"), assist: translation(".throttle"),
             speed: translation(".mph", mph: 20), motor: motor_cap, body: translation(".class_2_body")},
            {n: 3, title: translation(".class_n", n: 3), tag: translation(".class_3_tag"), assist: translation(".pedal"),
             speed: translation(".mph", mph: 28), motor: motor_cap, rules: class_3_rules,
             body: class_3_rules ? translation(".class_3_summary") : translation(".class_3_body")},
            emoto_card
          ]
        end

        def emoto_card
          rules = @state && EbikeRuleServices::StateLaws.emoto_rules(@state[:abbr]).presence
          {n: nil, either: true, title: render(Pages::EbikeRules::UnbrokenHyphens::Component.new(text: translation(".not_an_ebike"))),
           speed: translation(".emoto_speed"), motor: translation(".emoto_motor"), rules:,
           body: rules ? translation(".emoto_summary") : translation(".emoto_limits_body")}
        end
      end
    end
  end
end
