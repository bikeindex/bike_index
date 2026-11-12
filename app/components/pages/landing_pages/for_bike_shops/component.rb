# frozen_string_literal: true

module Pages
  module LandingPages
    module ForBikeShops
      class Component < ApplicationComponent
        include MoneyHelper

        SECTION_CLASSES = SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES
        MUTED = "tw:text-gray-500 tw:dark:text-gray-400"
        HEADING_CLASSES = "tw:m-0 tw:font-header tw:font-extrabold"
        BAND = "tw:border-gray-200 tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-800"
        BIKE_BOOK_MODELS = %w[m/trek/2026/domane_sl_6_gen_4 m/specialized/2026/tarmac_sl8_pro_shimano_ultegra_di2
          m/cannondale/2025/synapse_carbon_1].freeze
        # Bike Book's banner is taller below 1024px, which its frame reaches at 410px
        BIKE_BOOK_FRAME_CLASS = "tw:[--frame-crop-x:0px] tw:[--frame-crop-top:258px] tw:@min-[410px]:[--frame-crop-top:240px] tw:[--frame-scale:0.4]"
        PRIVACY_ICON = SharedBlocks::Marketing::SectionHeading::Component::EYEBROW_COLORS[:yellow]

        # checker_place: the visitor's, as /ebike_rules detects it, which the checker's frame shows
        def initialize(recovery_displays:, feedback:, current_user: nil, checker_place: nil)
          @recovery_displays = recovery_displays
          @feedback = feedback
          @current_user = current_user
          @checker_place = checker_place
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
          [{title: translation(".for_your_customers"), circle: "tw:bg-blue-600",
            rows: [["icons/gift.svg", translation(".free_registration"), translation(".free_registration_body")],
              ["icons/siren.svg", translation(".help_if_stolen"), translation(".help_if_stolen_body")],
              ["icons/shield-check.svg", translation(".data_stays_private"), translation(".data_stays_private_body")],
              ["icons/wrench.svg", translation(".free_tools_title"), with_tools_link(translation(".free_tools_fun_body"))]]},
            {title: translation(".for_your_shop"), circle: "tw:bg-purple-500",
             rows: [["icons/timer.svg", translation(".nothing_to_manage"), translation(".nothing_to_manage_body")],
               ["icons/heart-handshake.svg", translation(".a_reason_to_trust_you"), translation(".a_reason_to_trust_you_body")],
               ["icons/lucide-search.svg", translation(".safer_used_bike_sales"), translation(".safer_used_bike_sales_body")],
               ["icons/wrench.svg", translation(".free_tools_title"), with_tools_link(translation(".free_tools_choose_body"))]]}]
        end

        def with_tools_link(body)
          link = link_to("#free-tools", class: "twlink tw:font-semibold tw:whitespace-nowrap") do
            safe_join([translation(".see_the_tools"), tag.span("↓", aria: {hidden: true})], " ")
          end
          safe_join([body, link], " ")
        end

        def privacy_points
          [["icons/ban.svg", translation(".never_sold")], ["kelsey/registration_show/lock.svg", translation(".never_shared")],
            ["icons/bike.svg", translation(".used_only_for_bikes")]]
        end

        # The checker lays out at a fixed 900px, where its box's top doesn't move; tan(atan2()) divides two lengths
        def tools
          [{href: ebike_rules_path, icon: "icons/bolt.svg", circle: "tw:bg-blue-600",
            frame: ebike_rules_place_path(*(@checker_place&.dig(:code) || "US-CA").split("-"), manual: 1, top_speed: 20, watts: 750, throttle: 0),
            frame_class: "tw:[--frame-crop-x:0px] tw:[--frame-crop-top:250px] tw:[--frame-scale:tan(atan2(100cqw,900px))]",
            title: translation(".ebike_legality_checker"), body: translation(".ebike_legality_checker_body"),
            action: translation(".check_your_state")},
            {href: bikebook_path, icon: "icons/book-open.svg", circle: "tw:bg-purple-500",
             frame: bikebook_path(vehicle_models: BIKE_BOOK_MODELS.join(",")),
             frame_class: BIKE_BOOK_FRAME_CLASS,
             title: "Bike Book", body: translation(".bike_book_body"), action: translation(".browse_bike_book_spaced")}]
        end

        def sticker_prices
          [[translation(".suggested_retail_price"), translation(".suggested_retail")],
            [translation(".wholesale"), translation(".pricing_shown_in_cart")]]
        end

        def faqs
          [[translation(".faq_cost_question"), translation(".faq_cost_answer")],
            [translation(".faq_pos_question"), translation(".faq_pos_answer")],
            [translation(".faq_setup_question"), translation(".faq_setup_answer")],
            [translation(".faq_data_question"), translation(".faq_data_answer")],
            [translation(".faq_customer_question"), translation(".faq_customer_answer")],
            [translation(".faq_stickers_question"), translation(".faq_stickers_answer")]]
        end
      end
    end
  end
end
