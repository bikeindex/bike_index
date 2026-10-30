# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCommunityGroups
      class Component < ApplicationComponent
        SECTION_CLASSES = SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES
        COMIC_CARD = "tw:rounded-lg tw:border-3 tw:border-[#111] tw:bg-white tw:shadow-[4px_4px_0_#111] tw:dark:bg-gray-800"
        OUTLINE = "tw:border-2! tw:border-blue-600! tw:normal-case! tw:text-blue-600! tw:hover:bg-blue-600! tw:hover:text-white!"

        # GObike Buffalo's tweet, quoted verbatim, so it isn't translated
        TESTIMONIAL = "At press conf. announcing partnership w/ @BPDAlerts, @BikeIndex, Erie Cty. DA's office & local bike shops to register bikes, prevent theft"

        def initialize(recovery_displays:, total_bikes:, recoveries_count:, recoveries_value:, organizations_count:,
          sign_up_path:)
          @recovery_displays = recovery_displays
          @sign_up_path = sign_up_path
          @total_bikes = total_bikes
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
        end

        private

        def stats
          [[bikes_display, translation(".bikes_registered_free")],
            [number_display(@recoveries_count), translation(".stolen_bikes_recovered")],
            [render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)), translation(".value_returned_to_owners")],
            [safe_join([number_display(@organizations_count), "+"]), translation(".partner_organizations")]]
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
          [{color: "tw:text-blue-600 tw:dark:text-blue-400", title: translation(".step_spread_title"), body: translation(".step_spread_body")},
            {color: "tw:text-blue-600 tw:dark:text-blue-400", title: translation(".step_register_title"), body: translation(".step_register_body")},
            {color: "tw:text-[#cc0000] tw:dark:text-red-400",
             title: translation(".step_stolen_title_html", stolen: tag.span(translation(".stolen"), class: "tw:text-[#cc0000] tw:dark:text-red-400")),
             body: translation(".step_stolen_body")},
            {color: "tw:text-[#2e8b57] tw:dark:text-green-400", title: translation(".step_home_title"), body: translation(".step_home_body")}]
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

        def callout_classes = "tw:flex tw:items-center tw:gap-x-3.5 tw:text-base tw:text-gray-600 tw:dark:text-gray-300"

        def muted_classes = "tw:text-gray-600 tw:dark:text-gray-300"
      end
    end
  end
end
