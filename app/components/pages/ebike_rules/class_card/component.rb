# frozen_string_literal: true

module Pages
  module EbikeRules
    module ClassCard
      # A class as "E-bike classes, explained" cards it: a US class from its number, any other `classification`, or
      # else the e-moto, each with the `place`'s own rules for it. Unframed, it's a tooltip's body; in a `frame_id`,
      # the one BikeBook loads. A `catalog_id` closes it, a copy away
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-class-card"

        def initialize(e_bike_class: nil, classification: nil, place: nil, framed: true, frame_id: nil, catalog_id: nil)
          @e_bike_class = e_bike_class
          @catalog_id = catalog_id
          @classification = classification
          @place = place
          @framed = framed
          @frame_id = frame_id
        end

        private

        def card
          @card ||= if @e_bike_class
            us_card
          elsif classification
            classification_card
          else
            emoto_card
          end
        end

        # a state's class it folds into the e-moto is none
        def classification
          @classification unless @classification&.dig(:not_an_ebike)
        end

        def us_card
          rules = @place && (@e_bike_class == 3) && EbikeRuleServices::StateLaws.class_3_rules(@place[:abbr]).presence
          tag, body = case @e_bike_class
          when 1 then [translation(".class_1_tag"), translation(".class_1_body")]
          when 2 then [translation(".class_2_tag"), translation(".class_2_body")]
          else [translation(".class_3_tag"), rules ? translation(".class_3_summary") : translation(".class_3_body")]
          end
          {n: @e_bike_class, title: translation(".class_n", n: @e_bike_class), tag:, body:, rules:,
           assist: (@e_bike_class == 2) ? translation(".throttle") : translation(".pedal"),
           speed: translation(".mph", mph: (@e_bike_class == 3) ? 28 : 20), motor: translation(".motor_cap")}
        end

        def emoto_card
          rules = @place && EbikeRuleServices::StateLaws.emoto_rules(@place[:abbr]).presence
          {either: true, title: render(Pages::EbikeRules::UnbrokenHyphens::Component.new(text: translation(".not_an_ebike"))),
           speed: translation(".emoto_speed"), motor: translation(".emoto_motor"), rules:,
           body: rules ? translation(".emoto_summary") : translation(".emoto_limits_body")}
        end

        # Under its jurisdiction where the catalog names one; a place's own classes leave it out
        def classification_card
          {either: classification[:either], title: classification[:name], tag: classification[:jurisdiction], body: classification[:description],
           assist: classification[:throttle] ? translation(".throttle") : translation(".pedal"),
           speed: classification[:mph] && render(Pages::EbikeRules::RuleValue::Component.new(law: classification, id: :speed)), motor: watts}
        end

        def watts
          if classification[:watt_cap]
            translation(".watts_max", watts: classification[:watt_cap])
          elsif classification[:min_watts]
            translation(".watts_min", watts: classification[:min_watts])
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
      end
    end
  end
end
