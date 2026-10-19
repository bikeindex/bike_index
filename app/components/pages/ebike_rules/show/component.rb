# frozen_string_literal: true

module Pages
  module EbikeRules
    module Show
      # The form is a plain GET, so a result is a link. A Canadian page picks a province rather than a state, and says
      # nothing of the US
      class Component < ApplicationComponent
        EYEBROW_CLASSES = "tw:text-xs tw:font-bold tw:tracking-[.08em] tw:uppercase tw:text-blue-600 tw:dark:text-blue-400"
        HEADING_CLASSES = "tw:font-header tw:text-[clamp(26px,4vw,34px)] tw:leading-tight tw:font-extrabold"
        SECTION_CLASSES = "tw:mx-auto tw:max-w-[1120px] tw:px-[clamp(16px,4vw,32px)]"
        COUNTRY_MODAL_ID = "ebike-rules-switch-country"

        def initialize(lookup:, manifest_url:, registered_count:, recoveries_count:, page_title:, default_title:)
          @lookup = lookup
          @manifest_url = manifest_url
          @registered_count = registered_count
          @recoveries_count = recoveries_count
          @page_title = page_title
          @default_title = default_title
        end

        private

        # The place's own page; without JavaScript, the controller sends a chosen place there
        def form_path = @lookup.place ? ebike_rules_place_path(*@lookup.place[:code].split("-")) : ebike_rules_path

        def us? = @lookup.us?

        # A checked country's regions; for the US, its states, and the place outside the US whose page this is
        def place_options
          @place_options ||= combobox_options(us? ? EbikeRuleServices::Places.us_states | [@lookup.place].compact :
            EbikeRuleServices::Places.regions(@lookup.country))
        end

        # a country's own page has none of its regions picked
        def place_value = @lookup.place&.dig(:code)&.then { it unless EbikeRuleServices::Places::CHECKED_COUNTRIES.include?(it) }

        # Where clearing the place goes: the country's page
        def country_path = us? ? ebike_rules_path : ebike_rules_place_path(@lookup.country)

        def country_options
          places = EbikeRuleServices::Places.outside_us
          return combobox_options(places) if us?

          [{name: EbikeRuleServices::Places::COUNTRY_NAMES["US"], abbr: "US"}] +
            combobox_options(places.reject { EbikeRuleServices::Places.country(it) == @lookup.country })
        end

        # Each submits its code, and reads "California (CA)", or "New South Wales (AU-NSW)" outside the page's country
        def combobox_options(places) = places.map { {name: it[:name], abbr: it[:code].delete_prefix("#{@lookup.country}-"), value: it[:code]} }

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

        def detected? = @lookup.detected_place.present? && @lookup.place == @lookup.detected_place

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
          cap = EbikeRuleServices::Places::CANADA_SPEED_CAP_KMH
          return [{value: cap, label: translation(".kmh", kmh: cap)}, {value: cap + 1, label: translation(".over_kmh", kmh: cap)}] unless us?

          [{value: 20, label: translation(".mph", mph: 20)}, {value: 28, label: translation(".mph", mph: 28)},
            {value: 29, label: translation(".over_28_mph")}]
        end

        # The copy that names a state, the US's classes or its laws, and Canada's in their place
        def copy
          @copy ||= if us?
            {subheading: translation(".subheading"), state: translation(".state"), select_state: translation(".select_state"),
             state_error: translation(".state_error"), location_not_shared: translation(".location_not_shared"),
             not_in_country: translation(".not_in_us_html", switch_country:), watts_placeholder: translation(".watts_placeholder"),
             parents_body: translation(".parents_body"), parents_link: translation(".parents_link"),
             parent_step_1_body: translation(".parent_step_1_body"), parent_step_2_title: translation(".parent_step_2_title"),
             parent_step_2_body: translation(".parent_step_2_body"), banned_body: translation(".banned_body"),
             disclaimer: translation(".disclaimer")}
          else
            {subheading: translation(".subheading_canada"), state: translation(".province"), select_state: translation(".select_province"),
             state_error: translation(".province_error"), location_not_shared: translation(".location_not_shared_canada"),
             not_in_country: translation(".not_in_canada_html", switch_country:), watts_placeholder: translation(".watts_placeholder_canada"),
             parents_body: translation(".parents_body_canada"), parents_link: translation(".parents_link_canada"),
             parent_step_1_body: translation(".parent_step_1_body_canada"), parent_step_2_title: translation(".parent_step_2_title_canada"),
             parent_step_2_body: translation(".parent_step_2_body_canada"), banned_body: translation(".banned_body_canada"),
             disclaimer: translation(".disclaimer_canada")}
          end
        end

        def switch_country
          render(UI::Button::Component.new(text: translation(".switch_country"), color: :link, html_class: "twlink-underlined",
            commandfor: COUNTRY_MODAL_ID, command: "show-modal"))
        end

        def throttle_entries = [{value: 1, label: translation(".answer_yes")}, {value: 0, label: translation(".answer_no")}]

        def parent_steps
          [
            [translation(".parent_step_1_title"), copy[:parent_step_1_body]],
            [copy[:parent_step_2_title], copy[:parent_step_2_body]],
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
