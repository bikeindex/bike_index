# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCities
      class Component < ApplicationComponent
        SECTION_CLASSES = "tw:mx-auto tw:max-w-[1200px] tw:px-6"
        EYEBROW_CLASSES = "tw:mb-2.5 tw:text-[13px] tw:font-bold tw:tracking-[.08em] tw:uppercase"
        HEADING_CLASSES = "tw:mb-3.5 tw:font-header tw:text-[clamp(28px,3.4vw,38px)] tw:leading-[1.15] tw:font-extrabold tw:text-balance"
        INTRO_CLASSES = "tw:text-[17px] tw:leading-relaxed tw:text-pretty tw:text-gray-600 tw:dark:text-gray-300"
        CARD_CLASSES = "tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white tw:p-6 tw:shadow-sm tw:dark:border-gray-700 tw:dark:bg-gray-800"
        ICON_DISC_CLASSES = "tw:flex tw:size-11 tw:flex-none tw:items-center tw:justify-center tw:rounded-full tw:text-white"
        # A comic panel, like the drawn illustrations it holds
        STICKER_CLASSES = "tw:flex tw:items-center tw:gap-4 tw:rounded-lg tw:border-3 tw:border-black tw:bg-white tw:px-5 tw:py-4.5 tw:shadow-[4px_4px_0_#111] tw:dark:bg-gray-800"
        FEEDBACK_TYPE = "lead_for_city"

        def initialize(feedback: Feedback.new, current_user: nil)
          @feedback = feedback
          @current_user = current_user
          @total_bikes, @recoveries_value, @organizations = Counts.retrieve_many("total_bikes", "recoveries_value", "organizations")
        end

        private

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

        def top_speed_options
          [[translation(".checker_speed_20"), 20], [translation(".checker_speed_28"), 28], [translation(".checker_speed_over_28"), 29]]
        end

        def throttle_options = [[translation(".answer_no"), 0], [translation(".answer_yes"), 1]]

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
            [translation(".partnership_nonprofit_title"), translation(".partnership_nonprofit_body")],
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

        def next_steps = [translation(".contact_next_call"), translation(".contact_next_setup"), translation(".contact_next_training")]

        def lead_request_entries
          [{value: "demo", label: translation(".mode_demo")}, {value: "trial", label: translation(".mode_trial")}]
        end

        def role_options
          [translation(".role_city_staff"), translation(".role_law_enforcement"), translation(".role_school"),
            translation(".role_housing"), translation(".role_elected"), translation(".role_other")]
        end
      end
    end
  end
end
