# frozen_string_literal: true

module Pages
  module LandingPages
    module Ascend
      # has_shop: the visitor is signed in to a shop organization, which finishes step one
      class Component < ApplicationComponent
        SECTION_CLASSES = SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES
        MUTED = Pages::LandingPages::ForBikeShops::Component::MUTED
        HEADING_CLASSES = Pages::LandingPages::ForBikeShops::Component::HEADING_CLASSES
        ASCEND_GUIDE_URL = "https://help.ascendrms.com/reporting/send-purchase-and-registration-information-to-bike-index"
        SHOPS_EMAIL = "bikeshops@bikeindex.org"

        def initialize(has_shop: false)
          @has_shop = has_shop
        end

        private

        def security_faq_path = info_path("security-faq-pos-integrations")

        def shop_benefits
          [["icons/repeat.svg", translation(".nothing_to_do_at_checkout"), translation(".nothing_to_do_at_checkout_body")],
            ["icons/mail-check.svg", translation(".bikes_waiting_for_customers"), translation(".bikes_waiting_for_customers_body")],
            ["icons/lucide-layout-dashboard.svg", translation(".a_dashboard_for_your_shop"), translation(".a_dashboard_for_your_shop_body")]]
        end

        def privacy_points
          [["icons/ban.svg", translation(".never_sold_or_shared"), translation(".never_sold_or_shared_body")],
            ["icons/envelope.svg", translation(".one_email_to_claim_their_bike"), translation(".one_email_to_claim_their_bike_body"), true],
            ["icons/megaphone-off.svg", translation(".no_marketing_lists"), translation(".no_marketing_lists_body")],
            ["icons/user-check.svg", translation(".customers_stay_in_control"), translation(".customers_stay_in_control_body")]]
        end

        def customer_benefits
          [["icons/file-check.svg", translation(".peace_of_mind"), translation(".peace_of_mind_body")],
            ["icons/siren.svg", translation(".a_full_suite_of_recovery_tools"), translation(".a_full_suite_of_recovery_tools_body")],
            ["icons/users.svg", translation(".a_network_on_their_side"), translation(".a_network_on_their_side_body")]]
        end

        def steps
          [step_create_account,
            {title: translation(".turn_on_bike_index_in_ascend"), body: translation(".turn_on_bike_index_in_ascend_body"),
             button: {text: translation(".open_ascend_guide"), href: ASCEND_GUIDE_URL, target: "_blank", rel: "noopener"}},
            {title: translation(".send_us_the_password"), body: translation(".send_us_the_password_body", shops_email: SHOPS_EMAIL),
             button: {text: translation(".email_us"), href: "mailto:#{SHOPS_EMAIL}?subject=#{ERB::Util.url_encode(translation(".email_subject"))}"}}]
        end

        def step_create_account
          return {title: translation(".your_shop_is_on_bike_index"), body: translation(".your_shop_is_on_bike_index_body"), done: true} if @has_shop

          {title: translation(".create_your_shop_account"), body: translation(".create_your_shop_account_body"),
           button: {text: translation(".create_shop_account"), href: new_organization_path}}
        end
      end
    end
  end
end
