# frozen_string_literal: true

module Pages
  module EbikeRules
    module ClassCard
      # A class as "E-bike classes, explained" cards it: a US class from its number, with a state's Class 3 rules, the
      # e-moto without one, with a state's e-moto rules, or a state's own class as `card`. Unframed, it's a tooltip's body
      class Component < ApplicationComponent
        def initialize(e_bike_class: nil, card: nil, rules: nil, state_name: nil, framed: true)
          @e_bike_class = e_bike_class
          @card = card
          @rules = rules
          @state_name = state_name
          @framed = framed
        end

        private

        def card = @card ||= @e_bike_class ? us_card : emoto_card

        def us_card
          tag, body = case @e_bike_class
          when 1 then [translation(".class_1_tag"), translation(".class_1_body")]
          when 2 then [translation(".class_2_tag"), translation(".class_2_body")]
          else [translation(".class_3_tag"), @rules ? translation(".class_3_summary") : translation(".class_3_body")]
          end
          {n: @e_bike_class, title: translation(".class_n", n: @e_bike_class), tag:, body:, rules: @rules,
           assist: (@e_bike_class == 2) ? translation(".throttle") : translation(".pedal"),
           speed: translation(".mph", mph: (@e_bike_class == 3) ? 28 : 20), motor: translation(".motor_cap")}
        end

        def emoto_card
          {n: nil, either: true, title: render(Pages::EbikeRules::UnbrokenHyphens::Component.new(text: translation(".not_an_ebike"))),
           speed: translation(".emoto_speed"), motor: translation(".emoto_motor"), rules: @rules,
           body: @rules ? translation(".emoto_summary") : translation(".emoto_limits_body")}
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
