# frozen_string_literal: true

module Pages
  module LandingPages
    module Lightspeed
      # has_shop: the visitor is signed in to a shop organization, which finishes step one
      class Component < ApplicationComponent
        SECTION_CLASSES = SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES
        MUTED = Pages::LandingPages::ForBikeShops::Component::MUTED
        HEADING_CLASSES = Pages::LandingPages::ForBikeShops::Component::HEADING_CLASSES
        BAND = Pages::LandingPages::ForBikeShops::Component::BAND
        CONNECT_URL = "https://posintegration.bikeindex.org/sorrysaccount"
        LIGHTSPEED_URL = "https://www.lightspeedhq.com/pos/retail/bike-shop/?utm_medium=partner&utm_source=Reseller&utm_campaign=001G00000118MwjIAE&ref=001G00000118MwjIAE"
        SUPPORT_EMAIL = "gavin@bikeindex.org"

        def initialize(has_shop: false)
          @has_shop = has_shop
        end

        private

        def security_faq_path = info_path("security-faq-pos-integrations")

        def support_email_link = mail_to(SUPPORT_EMAIL, SUPPORT_EMAIL, class: "twlink")

        def shop_benefits
          [["icons/scan-barcode.svg", translation(".two_fields_at_checkout"), translation(".two_fields_at_checkout_body")],
            ["icons/mail-check.svg", translation(".bikes_waiting_for_customers"), translation(".bikes_waiting_for_customers_body")],
            ["icons/lucide-layout-dashboard.svg", translation(".a_dashboard_for_your_shop"), translation(".a_dashboard_for_your_shop_body")]]
        end

        def privacy_points
          [["icons/ban.svg", translation(".never_sold_or_shared"), translation(".never_sold_or_shared_body")],
            ["icons/envelope.svg", translation(".one_email_to_claim_their_bike"), translation(".one_email_to_claim_their_bike_body"), true],
            ["icons/workflow.svg", translation(".works_with_your_own_email_flow"), translation(".works_with_your_own_email_flow_body_html", email_link: support_email_link)],
            ["icons/user-x.svg", translation(".any_customer_can_opt_out"), translation(".any_customer_can_opt_out_body")]]
        end

        def customer_benefits
          [["icons/file-check.svg", translation(".peace_of_mind"), translation(".peace_of_mind_body")],
            ["icons/siren.svg", translation(".a_full_suite_of_recovery_tools"), translation(".a_full_suite_of_recovery_tools_body")],
            ["icons/users.svg", translation(".a_network_on_their_side"), translation(".a_network_on_their_side_body")]]
        end

        def steps
          [step_log_in,
            {title: translation(".connect_lightspeed_and_turn_on_automatic_registration"),
             body: translation(".connect_lightspeed_body"),
             button: {text: translation(".connect_lightspeed"), href: CONNECT_URL}}]
        end

        def step_log_in
          return {title: translation(".youre_logged_in"), body: translation(".this_step_is_done"), done: true} if @has_shop

          {title: translation(".log_in_to_your_dashboard"),
           body: translation(".no_shop_account_body_html", create_link: link_to(translation(".create_one_for_free"), new_user_path(return_to: new_organization_path), class: "twlink")),
           button: {text: translation(".log_in"), href: new_session_path}}
        end
      end
    end
  end
end
