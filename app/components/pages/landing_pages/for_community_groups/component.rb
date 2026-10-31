# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCommunityGroups
      class Component < ApplicationComponent
        SECTION_CLASSES = SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES
        COMIC_CARD = "tw:rounded-lg tw:border-3 tw:border-[#111] tw:bg-white tw:shadow-[4px_4px_0_#111] tw:dark:bg-gray-800"
        MUTED = "tw:text-gray-600 tw:dark:text-gray-300"
        CALLOUT = "tw:flex tw:items-center tw:gap-x-3.5 tw:text-base #{MUTED}"
        OUTLINE = "tw:border-2! tw:border-blue-600! tw:normal-case! tw:text-blue-600! tw:hover:bg-blue-600! tw:hover:text-white! " \
          "tw:dark:border-blue-400! tw:dark:text-blue-300! tw:dark:hover:bg-blue-500! tw:dark:hover:text-white!"

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

          "#{number_with_precision(@total_bikes / 1_000_000.0, precision: 1, round_mode: :floor, strip_insignificant_zeros: true)}M+"
        end

        def trust_items
          [["icons/heart-handshake.svg", translation(".free_forever")],
            ["icons/globe.svg", translation(".valid_anywhere")],
            ["icons/shield-check.svg", translation(".nonprofit")]]
        end

        def steps
          colors = SharedBlocks::Marketing::SectionHeading::Component::EYEBROW_COLORS
          [[colors[:blue], translation(".step_spread_title"), translation(".step_spread_body")],
            [colors[:blue], translation(".step_register_title"), translation(".step_register_body")],
            [colors[:red], translation(".step_stolen_title_html", stolen: tag.span(translation(".stolen"), class: colors[:red])),
              translation(".step_stolen_body")],
            ["tw:text-[#2e8b57] tw:dark:text-green-400", translation(".step_home_title"), translation(".step_home_body")]]
        end

        def ebike_topics
          [["icons/gauge.svg", translation(".know_your_class"), translation(".know_your_class_detail")],
            ["icons/battery-charging.svg", translation(".charge_it_safely"), translation(".charge_it_safely_detail")],
            ["icons/map-pin.svg", translation(".know_where_to_ride"), translation(".know_where_to_ride_detail")],
            ["icons/hard-hat.svg", translation(".ride_prepared"), translation(".ride_prepared_detail")],
            ["kelsey/registration_show/lock.svg", translation(".protect_it"), translation(".protect_it_detail")]]
        end

        def tools
          blue, purple = "tw:bg-blue-600", "tw:bg-purple-500"
          [["icons/building-2.svg", blue, translation(".tool_account_title"), translation(".tool_account_body")],
            ["icons/code.svg", blue, translation(".tool_embed_title"), translation(".tool_embed_body")],
            ["icons/tent.svg", purple, translation(".tool_drives_title"), translation(".tool_drives_body")],
            ["icons/megaphone.svg", purple, translation(".tool_ambassadors_title"), translation(".tool_ambassadors_body")],
            ["icons/bolt.svg", purple, translation(".tool_ebike_title"), translation(".tool_ebike_body")],
            ["icons/searcher.svg", blue, translation(".tool_search_title"), translation(".tool_search_body")]]
        end

        def get_started_links
          [[translation(".host_a_registration_drive"), news_path("san-jose-registers-local-school-bikes-using-bike-index-mobile-registra")],
            [translation(".embed_a_registration_form"), info_path("embed-a-bike-index-registration-form-on-your-website")],
            [translation(".become_an_ambassador"), news_path("bike-index-launches-ambassadors-program")]]
        end
      end
    end
  end
end
