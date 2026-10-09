# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCommunityGroups
      class Component < ApplicationComponent
        # The layout loads Montserrat at 400 and 700 only
        FONTS_URL = "https://fonts.googleapis.com/css2?family=Bangers&family=Montserrat:wght@800;900&display=swap"
        COMIC_CARD = "tw:rounded-lg tw:border-3 tw:border-[#111] tw:bg-white tw:shadow-[4px_4px_0_#111]"
        CARD = "tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white tw:shadow-[0_1px_3px_rgba(44,62,80,.12),0_1px_2px_rgba(44,62,80,.08)]"
        STORY_CARD = "tw:flex tw:w-full tw:flex-col tw:overflow-hidden tw:text-gray-700 tw:no-underline #{CARD}"
        LINKED_STORY_CARD = "tw:transition-all tw:duration-300 tw:hover:-translate-y-1.25 tw:hover:text-gray-700 tw:hover:shadow-[0_4px_12px_rgba(44,62,80,.12)]"
        OUTLINE = "tw:border-2! tw:border-blue-600! tw:normal-case! tw:text-blue-600! tw:hover:bg-blue-600! tw:hover:text-white!"

        # GObike Buffalo's tweet, quoted verbatim, so it isn't translated
        TESTIMONIAL = "At press conf. announcing partnership w/ @BPDAlerts, @BikeIndex, Erie Cty. DA's office & local bike shops to register bikes, prevent theft"

        def initialize(recovery_displays:, total_bikes:, recoveries_count:, recoveries_value:, organizations_count:,
          sign_up_path:)
          @recovery_displays = recovery_displays.first(3)
          @sign_up_path = sign_up_path
          @total_bikes = total_bikes
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
        end

        def before_render
          helpers.content_for(:header) { stylesheet_link_tag(FONTS_URL) }
        end

        private

        def stats
          [{value: bikes_display, label: translation(".bikes_registered_free")},
            {value: number_display(@recoveries_count), label: translation(".stolen_bikes_recovered")},
            {value: render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)),
             label: translation(".value_returned_to_owners")},
            {value: safe_join([number_display(@organizations_count), "+"]),
             label: translation(".partner_organizations")}]
        end

        def bikes_display
          return number_display(@total_bikes) if @total_bikes < 1_000_000

          millions = (@total_bikes / 100_000).fdiv(10)
          safe_join([number_display((millions % 1).zero? ? millions.to_i : millions), "M+"])
        end

        def trust_items
          [["icons/heart-handshake.svg", translation(".free_forever")],
            ["icons/globe.svg", translation(".valid_anywhere")],
            ["icons/shield-check.svg", translation(".nonprofit")]]
        end

        def steps
          [{color: "tw:text-blue-600", title: translation(".step_spread_title"), body: translation(".step_spread_body")},
            {color: "tw:text-blue-600", title: translation(".step_register_title"), body: translation(".step_register_body")},
            {color: "tw:text-[#cc0000]",
             title: translation(".step_stolen_title_html", stolen: tag.span(translation(".stolen"), class: "tw:text-[#cc0000]")),
             body: translation(".step_stolen_body")},
            {color: "tw:text-[#2e8b57]", title: translation(".step_home_title"), body: translation(".step_home_body")}]
        end

        def ebike_topics
          [["icons/gauge.svg", translation(".know_your_class"), translation(".know_your_class_detail")],
            ["icons/battery-charging.svg", translation(".charge_it_safely"), translation(".charge_it_safely_detail")],
            ["icons/map-pin.svg", translation(".know_where_to_ride"), translation(".know_where_to_ride_detail")],
            ["icons/hard-hat.svg", translation(".ride_prepared"), translation(".ride_prepared_detail")],
            ["kelsey/registration_show/lock.svg", translation(".protect_it"), translation(".protect_it_detail")]]
        end

        def tools
          [{icon: "icons/building-2.svg", circle: "tw:bg-blue-600",
            title: translation(".tool_account_title"), body: translation(".tool_account_body")},
            {icon: "icons/code.svg", circle: "tw:bg-blue-600",
             title: translation(".tool_embed_title"), body: translation(".tool_embed_body")},
            {icon: "icons/tent.svg", circle: "tw:bg-purple-500",
             title: translation(".tool_drives_title"), body: translation(".tool_drives_body")},
            {icon: "icons/megaphone.svg", circle: "tw:bg-purple-500",
             title: translation(".tool_ambassadors_title"), body: translation(".tool_ambassadors_body")},
            {icon: "icons/bolt.svg", circle: "tw:bg-purple-500",
             title: translation(".tool_ebike_title"), body: translation(".tool_ebike_body")},
            {icon: "icons/searcher.svg", circle: "tw:bg-blue-600",
             title: translation(".tool_search_title"), body: translation(".tool_search_body")}]
        end

        def get_started_links
          [[translation(".host_a_registration_drive"), news_path("san-jose-registers-local-school-bikes-using-bike-index-mobile-registra")],
            [translation(".embed_a_registration_form"), info_path("embed-a-bike-index-registration-form-on-your-website")],
            [translation(".become_an_ambassador"), news_path("bike-index-launches-ambassadors-program")]]
        end

        def container = "tw:mx-auto tw:max-w-300 tw:px-6"

        def eyebrow_classes = "tw:m-0 tw:mb-2 tw:text-[13px] tw:font-bold tw:tracking-[.08em] tw:uppercase"

        def h2_classes = "tw:m-0 tw:font-header tw:font-extrabold tw:text-balance tw:text-slate-900"

        def callout_classes = "tw:flex tw:flex-wrap tw:items-center tw:gap-x-3.5 tw:gap-y-2.5 tw:text-base tw:text-gray-600"
      end
    end
  end
end
