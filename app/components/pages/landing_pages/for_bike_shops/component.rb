# frozen_string_literal: true

module Pages
  module LandingPages
    module ForBikeShops
      class Component < ApplicationComponent
        include MoneyHelper

        COMIC_BOX = "tw:rounded-lg tw:border-3 tw:border-black tw:bg-white tw:shadow-[4px_4px_0_#000]"

        def initialize(total_bikes:, recoveries_count:, recoveries_value:, organizations_count:, recovery_displays:,
          feedback:, signed_up: false, current_user: nil)
          @total_bikes = total_bikes
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
          @recovery_displays = recovery_displays.first(3)
          @feedback = feedback
          @signed_up = signed_up
          @current_user = current_user
        end

        private

        def hero_stats
          # number_display dims a zero, and this one is the claim
          [[safe_join([number_display(10), translation(".min")], " "), translation(".to_set_up")],
            [as_currency(0), translation(".for_you_and_your_customers")],
            [number_with_delimiter(0), translation(".customer_records_sold_or_shared")]]
        end

        # The values are what staff read in the lead's body, so they stay untranslated
        def pos_options
          [[translation(".pos_lightspeed"), "POS: Lightspeed"],
            [translation(".pos_ascend"), "POS: Ascend"],
            [translation(".pos_shopify_coming_soon"), "POS: Shopify"],
            [translation(".pos_other_or_none"), "POS: Other / none"]]
        end

        def integrations
          [["Lightspeed", true], ["Ascend", true], ["Shopify", false]]
        end

        def steps
          [[translation(".step_connect_title"), translation(".step_connect_body")],
            [translation(".step_sell_title"), translation(".step_sell_body")],
            [translation(".step_covered_title"), translation(".step_covered_body")]]
        end

        def benefit_cards
          [{title: translation(".for_your_customers"), burst: translation(".safe"), color: "tw:text-blue-600",
            rows: [["icons/gift.svg", translation(".free_registration"), translation(".free_registration_body")],
              ["icons/siren.svg", translation(".help_if_stolen"), translation(".help_if_stolen_body")],
              ["icons/shield-check.svg", translation(".data_stays_private"), translation(".data_stays_private_body")]]},
            {title: translation(".for_your_shop"), burst: translation(".pow"), color: "tw:text-purple-500",
             rows: [["icons/timer.svg", translation(".nothing_to_manage"), translation(".nothing_to_manage_body")],
               ["icons/heart-handshake.svg", translation(".a_reason_to_trust_you"), translation(".a_reason_to_trust_you_body")],
               ["icons/searcher.svg", translation(".safer_used_bike_sales"), translation(".safer_used_bike_sales_body")]]}]
        end

        def impact_stats
          [[number_display(@total_bikes), translation(".bikes_registered_free")],
            [number_display(@recoveries_count), translation(".stolen_bikes_recovered")],
            [render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)),
              translation(".value_returned_to_owners")],
            [safe_join([number_display(@organizations_count), "+"]), translation(".partner_organizations")]]
        end

        def privacy_points
          [["icons/ban.svg", translation(".never_sold")], ["icons/lock.svg", translation(".never_shared")],
            ["icons/bike.svg", translation(".used_only_for_bikes")]]
        end

        def tools
          [{href: ebike_rules_path, icon: "icons/bolt.svg", circle: "tw:bg-blue-600",
            title: translation(".ebike_legality_checker"), body: translation(".ebike_legality_checker_body"),
            action: translation(".check_your_state")},
            {href: bikebook_path, icon: "icons/book-open.svg", circle: "tw:bg-purple-500",
             title: translation(".bike_book"), body: translation(".bike_book_body"), action: translation(".browse_bike_book")}]
        end

        def faqs
          [[translation(".faq_cost_question"), translation(".faq_cost_answer")],
            [translation(".faq_pos_question"), translation(".faq_pos_answer")],
            [translation(".faq_setup_question"), translation(".faq_setup_answer")],
            [translation(".faq_data_question"), translation(".faq_data_answer")],
            [translation(".faq_customer_question"), translation(".faq_customer_answer")],
            [translation(".faq_stickers_question"), translation(".faq_stickers_answer")]]
        end

        def support_email = "support@bikeindex.org"

        def eyebrow_classes = "tw:m-0 tw:mb-2 tw:text-[13px] tw:font-bold tw:tracking-widest tw:uppercase"

        def h2_classes = "tw:m-0 tw:font-header tw:font-extrabold tw:text-slate-900"

        def section_inner = "tw:mx-auto tw:max-w-300 tw:px-6"

        def navy_gradient = "tw:bg-linear-160 tw:from-slate-900 tw:to-[#233140] tw:text-white"
      end
    end
  end
end
