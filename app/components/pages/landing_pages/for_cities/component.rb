# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCities
      class Component < ApplicationComponent
        SECTION_CLASSES = "tw:mx-auto tw:max-w-[1200px] tw:px-6"
        EYEBROW_CLASSES = "tw:mb-2.5 tw:text-[13px] tw:font-bold tw:tracking-[.08em] tw:uppercase"
        HEADING_CLASSES = "tw:mb-3.5 tw:font-header tw:text-[clamp(28px,3.4vw,38px)] tw:leading-[1.15] tw:font-extrabold tw:text-balance"
        INTRO_CLASSES = "tw:text-[17px] tw:leading-relaxed tw:text-pretty tw:text-gray-600 tw:dark:text-gray-300"
        ICON_DISC_CLASSES = "tw:flex tw:size-11 tw:flex-none tw:items-center tw:justify-center tw:rounded-full tw:text-white"
        MODAL_ID = "cities-demo-modal"
        # The hero's mockups sit in phone frames, so they read as screenshots rather than fields to fill
        # in. zoom shrinks a whole phone, so the two stay side by side on a small screen
        PHONE_CLASSES = "tw:mx-auto tw:flex tw:w-full tw:max-w-[340px] tw:min-w-0 tw:min-h-[640px] tw:flex-col tw:rounded-[2.25rem] tw:bg-slate-900 tw:p-2 tw:shadow-[0_18px_40px_rgba(44,62,80,.28)] " \
          "tw:[zoom:0.45] tw:min-[480px]:[zoom:0.6] tw:min-[640px]:[zoom:0.8] tw:min-[800px]:[zoom:1]"
        PHONE_SCREEN_CLASSES = "tw:flex-1 tw:overflow-hidden tw:rounded-[1.75rem] tw:bg-[#f3f4f6] tw:text-gray-900"

        # checker_state: the abbreviation of the visitor's state, which the checker starts on
        def initialize(feedback: Feedback.new, checker_state: nil)
          @feedback = feedback
          @checker_state = checker_state
          @total_bikes, @recoveries_value, @organizations = Counts.retrieve_many("total_bikes", "recoveries_value", "organizations")
        end

        private

        def phone_status_bar
          tag.div(class: "tw:relative tw:flex tw:items-center tw:justify-between tw:px-6 tw:pt-2.5 tw:pb-1 tw:text-[11px] tw:font-semibold") do
            safe_join([tag.span("9:41"),
              tag.span(class: "tw:absolute tw:top-2 tw:left-1/2 tw:h-5 tw:w-20 tw:-translate-x-1/2 tw:rounded-full tw:bg-slate-900"),
              tag.span(class: "tw:flex tw:h-2.5 tw:w-5 tw:rounded-[3px] tw:border tw:border-gray-900 tw:p-px") { tag.span(class: "tw:w-3/4 tw:rounded-[1px] tw:bg-gray-900") }])
          end
        end

        def stats
          [
            [number_display(@total_bikes), translation(".stat_bikes")],
            [render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)), translation(".stat_recovered")],
            [safe_join([number_display(@organizations), "+"]), translation(".stat_organizations")],
            [translation(".stat_agencies_count"), translation(".stat_agencies")]
          ]
        end

        def nav_links
          [
            ["#registration", translation(".nav_registration")],
            ["#recovery", translation(".nav_recovery")],
            ["#education", translation(".nav_education")],
            ["#checker", translation(".nav_checker")],
            ["#faq", translation(".nav_faq")]
          ]
        end

        def program_cards
          [
            {href: "#registration", icon: "icons/clipboard.svg", color: "tw:bg-blue-600", number: "01",
             title: translation(".program_registration_title"), body: translation(".program_registration_body"),
             link: translation(".program_registration_link")},
            {href: "#education", icon: "icons/bolt.svg", color: "tw:bg-purple-500", new: true,
             title: translation(".program_education_title"), body: translation(".program_education_body"),
             link: translation(".program_education_link")},
            {href: "#recovery", icon: "icons/megaphone.svg", color: "tw:bg-[#cc0000]", number: "02",
             title: translation(".program_recovery_title"), body: translation(".program_recovery_body"),
             link: translation(".program_recovery_link")}
          ]
        end

        def registration_steps
          [
            [translation(".registration_step_1_title"), translation(".registration_step_1_body")],
            [translation(".registration_step_2_title"), translation(".registration_step_2_body")],
            [translation(".registration_step_3_title"), translation(".registration_step_3_body")],
            [translation(".registration_step_4_title"), translation(".registration_step_4_body")]
          ]
        end

        def recovery_steps
          [
            ["tw:bg-[#cc0000]", translation(".recovery_step_1_title"), translation(".recovery_step_1_body")],
            ["tw:bg-slate-900", translation(".recovery_step_2_title"), translation(".recovery_step_2_body")],
            ["tw:bg-blue-600", translation(".recovery_step_3_title"), translation(".recovery_step_3_body")]
          ]
        end

        def child_organizations
          [
            [translation(".child_school_name"), translation(".child_school_note")],
            [translation(".child_housing_name"), translation(".child_housing_note")],
            [translation(".child_neighborhood_name"), translation(".child_neighborhood_note")]
          ]
        end

        def hierarchy_points
          [
            {icon: "icons/map-pin.svg", color: "tw:bg-slate-900", title: translation(".hierarchy_city_title"), body: translation(".hierarchy_city_body")},
            {icon: "icons/users.svg", color: "tw:bg-purple-500", title: translation(".hierarchy_programs_title"), body: translation(".hierarchy_programs_body")},
            {icon: "icons/bar-chart.svg", color: "tw:bg-blue-600", title: translation(".hierarchy_dashboard_title"), body: translation(".hierarchy_dashboard_body")}
          ]
        end

        def checker_points
          [translation(".checker_point_bikebook"), translation(".checker_point_states"), translation(".checker_point_program")]
        end

        def state_options = EbikeRuleServices::Places.combobox_options(EbikeRuleServices::Places.us_states, country: "US")

        def top_speed_entries
          [{value: 20, label: translation(".checker_speed_20")}, {value: 28, label: translation(".checker_speed_28")},
            {value: 29, label: translation(".checker_speed_over_28")}]
        end

        def throttle_entries = [{value: 1, label: translation(".answer_yes")}, {value: 0, label: translation(".answer_no")}]

        def field_tools
          [
            {icon: "icons/qr-code.svg", color: "tw:bg-purple-500", title: translation(".field_qr_title"), body: translation(".field_qr_body")},
            {icon: "icons/searcher.svg", color: "tw:bg-blue-600", title: translation(".field_serial_title"), body: translation(".field_serial_body")},
            {icon: "icons/check.svg", color: "tw:bg-slate-900", title: translation(".field_attestations_title"), body: translation(".field_attestations_body")},
            {icon: "icons/bolt.svg", color: "tw:bg-blue-600", title: translation(".field_battery_title"), body: translation(".field_battery_body")}
          ]
        end

        def partnership_points
          [
            [translation(".partnership_fees_title"), translation(".partnership_fees_body")],
            [translation(".partnership_data_title"), translation(".partnership_data_body")],
            [translation(".partnership_support_title"), translation(".partnership_support_body")]
          ]
        end

        def faqs
          [
            [translation(".faq_checker_question"), translation(".faq_checker_answer")],
            [translation(".faq_account_question"), translation(".faq_account_answer")],
            [translation(".faq_rules_question"), translation(".faq_rules_answer")],
            [translation(".faq_cost_question"), translation(".faq_cost_answer")],
            [translation(".faq_regular_question"), translation(".faq_regular_answer")],
            [translation(".faq_police_question"), translation(".faq_police_answer")],
            [translation(".faq_import_question"), translation(".faq_import_answer")]
          ]
        end

        def next_steps = [translation(".contact_next_priorities"), translation(".contact_next_walkthrough"), translation(".contact_next_plan")]

        # Keys that humanize to the English label, so the admin email reads the same in any locale
        def role_options
          [[translation(".role_city_staff"), "city_staff"], [translation(".role_law_enforcement"), "law_enforcement"],
            [translation(".role_school"), "school_or_district"], [translation(".role_housing"), "housing_or_community_program"],
            [translation(".role_elected"), "elected_official"], [translation(".role_other"), "other"]]
        end
      end
    end
  end
end
