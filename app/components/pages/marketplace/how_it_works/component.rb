# frozen_string_literal: true

module Pages
  module Marketplace
    module HowItWorks
      class Component < ApplicationComponent
        SECTION_CLASSES = SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES
        BODY_CLASSES = "tw:text-gray-600 tw:dark:text-gray-300"

        private

        def checks
          [{icon: "icons/bike.svg", title: translation(".registered_bikes_only"), body: translation(".registered_bikes_only_body")},
            {icon: "icons/searcher.svg", title: translation(".checked_for_theft"), body: translation(".checked_for_theft_body")},
            {icon: "icons/handshake.svg", title: translation(".ownership_transfers"), body: translation(".ownership_transfers_body")},
            {icon: "icons/badge-check.svg", title: translation(".bike_index_members"), body: translation(".bike_index_members_body")}]
        end

        def delivery_options
          [[translation(".local_pickup"), translation(".local_pickup_body")],
            [translation(".shipping"), translation(".shipping_body")]]
        end

        def step_lists
          [
            ["buying", translation(".buying_a_bike"), [
              [translation(".find_a_bike"), translation(".find_a_bike_body")],
              [translation(".contact_the_seller"), translation(".contact_the_seller_member_badge_body")],
              [translation(".see_it_or_ship_it"), translation(".see_it_or_ship_it_body")],
              [translation(".pay_and_take_ownership"), translation(".pay_and_take_ownership_body")]
            ], "tw:bg-blue-600"],
            ["selling", translation(".selling_a_bike"), [
              [translation(".register_your_bike"), translation(".register_your_bike_body")],
              [translation(".mark_it_for_sale"), translation(".mark_it_for_sale_body")],
              [translation(".hand_off_or_ship"), translation(".hand_off_or_ship_body")],
              [translation(".transfer_ownership"), translation(".transfer_ownership_body")]
            ], "tw:bg-purple-500"]
          ]
        end

        def safety_tips
          [translation(".tip_public_place"), translation(".tip_check_serial"), translation(".tip_shipping"),
            translation(".tip_be_wary"), translation(".tip_registration_transferred")]
        end

        def call_to_action_buttons
          tag.div(class: "tw:flex tw:flex-wrap tw:gap-3") do
            render(UI::ButtonLink::Component.new(href: search_marketplace_path, text: translation(".browse_bikes"),
              color: :yellow, size: :callout)) +
              render(UI::ButtonLink::Component.new(href: my_account_path, text: translation(".sell_your_bike"),
                color: :secondary, size: :callout))
          end
        end
      end
    end
  end
end
