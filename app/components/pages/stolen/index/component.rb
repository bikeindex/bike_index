# frozen_string_literal: true

module Pages
  module Stolen
    module Index
      # The first page someone reaches after a theft. Below lg it's the design's mobile
      # layout, which drops the promoted alerts band, the FAQ and the resources
      class Component < ApplicationComponent
        PILL = "tw:rounded-full! tw:font-semibold! tw:transition-all!"
        CTA = "#{PILL} tw:px-6! tw:py-4! tw:text-[15.5px]! tw:uppercase tw:tracking-wider " \
          "tw:hover:-translate-y-0.5 tw:hover:brightness-110"
        STORY_COUNT = 4

        def initialize(recoveries_count:, recoveries_value:, organizations_count:, recovery_displays:)
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
          @recovery_displays = recovery_displays.first(STORY_COUNT)
        end

        private

        def register_stolen_path = new_bike_path(stolen: true)

        def recoveries_value_millions = (@recoveries_value / 100_000) / 10.0

        def stats
          [{value: number_display(@recoveries_count), label: translation(".stolen_bikes_recovered")},
            {value: safe_join(["$", number_display(recoveries_value_millions), "M"]),
             label: translation(".value_returned_to_owners")},
            {value: safe_join([number_display(@organizations_count), "+"]),
             label: translation(".partner_organizations")},
            {value: "$0", label: translation(".to_register_always")}]
        end

        def steps
          [{title: translation(".step_police_title"), tag: translation(".step_police_tag"),
            body: translation(".step_police_body"), action: translation(".step_police_action"),
            href: get_your_stolen_bike_back_path},
            {title: translation(".step_register_title"), tag: translation(".step_register_tag"),
             body: translation(".step_register_body"), action: translation(".step_register_action"),
             href: register_stolen_path},
            {title: translation(".step_listing_title"), tag: translation(".step_listing_tag"),
             body: translation(".step_listing_body"), action: translation(".step_listing_action"),
             href: my_account_path},
            {title: translation(".step_alert_title"), tag: translation(".step_alert_tag"),
             body: translation(".step_alert_body"), action: translation(".step_alert_action"),
             href: promoted_alerts_path},
            {title: translation(".step_google_alerts_title"), tag: translation(".step_google_alerts_tag"),
             body: translation(".step_google_alerts_body"), action: translation(".step_google_alerts_action"),
             href: "https://www.google.com/alerts"},
            {title: translation(".step_shops_title"), tag: translation(".step_shops_tag"),
             body: translation(".step_shops_body"), action: translation(".step_shops_action"),
             href: where_path}]
        end

        def step_classes(priority)
          priority ? "tw:bg-blue-100 tw:border-blue-200" : "tw:bg-white tw:border-gray-200 tw:hover:border-blue-200"
        end

        def step_tag_classes(priority)
          priority ? "tw:bg-blue-100 tw:border-blue-200 tw:text-blue-600" : "tw:bg-gray-100 tw:border-gray-200 tw:text-gray-500"
        end

        def step_action(step, priority)
          UI::ButtonLink::Component.new(href: step[:href], text: step[:action], color: :primary,
            html_class: [PILL, "tw:px-4! tw:py-2! tw:text-[13.5px]! tw:lg:px-5! tw:lg:py-2.5! tw:lg:text-sm!",
              ("tw:bg-blue-100! tw:border-blue-200! tw:text-blue-600! tw:hover:bg-blue-200!" unless priority)].compact.join(" "))
        end

        def pillars
          [{icon: "icons/searcher.svg", circle: "tw:bg-blue-600",
            title: translation(".pillar_serial_title"), body: translation(".pillar_serial_body")},
            {icon: "icons/users.svg", circle: "tw:bg-purple-500",
             title: translation(".pillar_network_title"), body: translation(".pillar_network_body")},
            {icon: "icons/megaphone.svg", circle: "tw:bg-slate-900",
             title: translation(".pillar_alerts_title"), body: translation(".pillar_alerts_body")}]
        end

        def faqs
          [{question: translation(".faq_serial_question"), answer: translation(".faq_serial_answer")},
            {question: translation(".faq_unregistered_question"), answer: translation(".faq_unregistered_answer")},
            {question: translation(".faq_confront_question"), answer: translation(".faq_confront_answer")},
            {question: translation(".faq_other_city_question"), answer: translation(".faq_other_city_answer")},
            {question: translation(".faq_cost_question"), answer: translation(".faq_cost_answer")}]
        end

        def resources
          [[translation(".resource_what_to_do"), get_your_stolen_bike_back_path],
            [translation(".resource_safety_tips"), news_path("bike-safety-tips-for-recovering-your-own-bicycle")],
            [translation(".resource_register_found"), register_path(status: "found")],
            [translation(".resource_portland"), news_path("what-to-do-when-your-bike-is-stolen-in-portland-oregon")],
            [translation(".resource_seattle"), news_path("what-to-do-when-your-bike-has-been-stolen-in-seattle")],
            [translation(".resource_bay_area"), news_path("what-to-do-when-your-bike-has-been-stolen-in-the-bay-area")],
            [translation(".resource_why_register"), news_path("why-register-your-bikes-on-bike-index")]]
        end

        def promoted_alerts_path = news_path("bike-indexs-new-promoted-alerts-are-the-megaphone-crooks-dont-want-you")

        def section_inner = "tw:mx-auto tw:max-w-6xl tw:px-5 tw:py-6 tw:lg:px-14 tw:lg:py-12"

        def h2_classes = "tw:m-0 tw:font-header tw:text-[23px] tw:font-extrabold tw:text-slate-900 tw:lg:text-[34px]"
      end
    end
  end
end
