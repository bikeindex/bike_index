# frozen_string_literal: true

module Pages
  module EbikeRules
    module Show
      # The e-bike compliance checker: a state and a bike in, the state's rules for that bike out,
      # then the explainers and every state's rules. The form is a plain GET, so a result is a link
      class Component < ApplicationComponent
        EYEBROW_CLASSES = "tw:text-xs tw:font-bold tw:tracking-[.08em] tw:uppercase tw:text-blue-600 tw:dark:text-blue-400"
        HEADING_CLASSES = "tw:font-header tw:text-[clamp(26px,4vw,34px)] tw:leading-tight tw:font-extrabold"
        SECTION_CLASSES = "tw:mx-auto tw:max-w-[1120px] tw:px-[clamp(16px,4vw,32px)]"

        def initialize(lookup:, manifest_url:, registered_count:, recoveries_count:)
          @lookup = lookup
          @manifest_url = manifest_url
          @registered_count = registered_count
          @recoveries_count = recoveries_count
        end

        private

        def state_option_tags
          states = ::EbikeRules::StateLaws::STATES.map { [it[:name], it[:abbr]] }
          options_for_select(states, @lookup.state&.dig(:abbr))
        end

        def error?(field) = @lookup.errors.include?(field)

        def detected? = @lookup.detected_state.present? && @lookup.state == @lookup.detected_state

        # The selected model's name, which the combobox shows once the catalog loads
        def bike_display
          bike = @lookup.bike
          [bike.make_and_model, bike.first_year].compact.join(" ") if bike && !bike.manual?
        end

        def class_entries = [1, 2, 3].map { {value: it, label: translation(".class_n", n: it)} }

        def throttle_entries = [{value: 1, label: translation(".answer_yes")}, {value: 0, label: translation(".answer_no")}]

        def class_cards
          [
            {n: 1, tag: translation(".class_1_tag"), assist: translation(".pedal"), speed: translation(".mph", mph: 20), body: translation(".class_1_body")},
            {n: 2, tag: translation(".class_2_tag"), assist: translation(".throttle"), speed: translation(".mph", mph: 20), body: translation(".class_2_body")},
            {n: 3, tag: translation(".class_3_tag"), assist: translation(".pedal"), speed: translation(".mph", mph: 28), body: translation(".class_3_body")}
          ]
        end

        def parent_steps
          [
            [translation(".parent_step_1_title"), translation(".parent_step_1_body")],
            [translation(".parent_step_2_title"), translation(".parent_step_2_body")],
            [translation(".parent_step_3_title"), translation(".parent_step_3_body")],
            [translation(".parent_step_4_title"), translation(".parent_step_4_body")],
            [translation(".parent_step_5_title"), translation(".parent_step_5_body")],
            [translation(".parent_step_6_title"), translation(".parent_step_6_body")]
          ]
        end

        def ul_standards
          [
            {code: "UL 2849", scope: translation(".ul_2849_scope"), body: translation(".ul_2849_body"),
             tests: [translation(".ul_2849_test_1"), translation(".ul_2849_test_2"), translation(".ul_2849_test_3")]},
            {code: "UL 2271", scope: translation(".ul_2271_scope"), body: translation(".ul_2271_body"),
             tests: [translation(".ul_2271_test_1"), translation(".ul_2271_test_2"), translation(".ul_2271_test_3")]}
          ]
        end
      end
    end
  end
end
