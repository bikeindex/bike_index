# frozen_string_literal: true

module Pages
  module EbikeRules
    module Show
      # The form is a plain GET, so a result is a link
      class Component < ApplicationComponent
        EYEBROW_CLASSES = "tw:text-xs tw:font-bold tw:tracking-[.08em] tw:uppercase tw:text-blue-600 tw:dark:text-blue-400"
        HEADING_CLASSES = "tw:font-header tw:text-[clamp(26px,4vw,34px)] tw:leading-tight tw:font-extrabold"
        SECTION_CLASSES = "tw:mx-auto tw:max-w-[1120px] tw:px-[clamp(16px,4vw,32px)]"

        def initialize(lookup:, manifest_url:, registered_count:, recoveries_count:, page_title:, default_title:)
          @lookup = lookup
          @manifest_url = manifest_url
          @registered_count = registered_count
          @recoveries_count = recoveries_count
          @page_title = page_title
          @default_title = default_title
        end

        private

        # The state's own page; without JavaScript, the controller sends a chosen state there
        def form_path = @lookup.state ? ebike_rules_state_path(@lookup.state[:abbr].downcase) : ebike_rules_path

        def field_error(field, text)
          return unless error?(field)

          tag.p(text, role: "alert", class: "tw:text-[13px] tw:font-semibold tw:text-red-700 tw:dark:text-red-400")
        end

        def error?(field) = @lookup.errors.include?(field)

        # Which of the bike's two inputs the check is of: the picked model, details changed from it, or details alone
        def details_mode
          if @lookup.custom?
            "custom"
          elsif @lookup.bikebook_id
            "model"
          else
            "manual"
          end
        end

        def detected? = @lookup.detected_state.present? && @lookup.state == @lookup.detected_state

        # The picked model. Custom details are the checked bike, so it's looked up on its own
        def model
          return @model if defined?(@model)

          @model = @lookup.bikebook_id && (@lookup.custom? ? EbikeRuleServices::BikebookVehicles.find(@lookup.bikebook_id) : @lookup.bike)
        end

        # The model's name, which the combobox shows once the catalog loads
        def bike_display = model && [model.make_and_model, model.first_year].compact.join(" ")

        # Named for the model, which the browser renames for a later pick
        def details_legend = model ? translation(".model_details", model: model.make_and_model) : translation(".details_legend")

        def top_speed_entries
          [{value: 20, label: translation(".mph", mph: 20)}, {value: 28, label: translation(".mph", mph: 28)},
            {value: 29, label: translation(".over_28_mph")}]
        end

        def throttle_entries = [{value: 1, label: translation(".answer_yes")}, {value: 0, label: translation(".answer_no")}]

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
