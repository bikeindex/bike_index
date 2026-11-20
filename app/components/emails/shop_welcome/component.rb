# frozen_string_literal: true

module Emails
  module ShopWelcome
    # A full document rather than a fragment: OrganizedMailer#shop_welcome renders it without the
    # email layout. Table markup and inline styles, because email clients ignore everything else -
    # only the mobile media query lives in a <style>
    class Component < ApplicationComponent
      FONT = "font-family:Arial,Helvetica,sans-serif;mso-line-height-rule:exactly;"

      def initialize(organization:)
        @organization = organization
      end

      private

      def font_style(size, line, color, weight: nil, extra: nil)
        "#{FONT}font-size:#{size}px;line-height:#{line}px;color:#{color};#{"font-weight:#{weight};" if weight}#{extra}"
      end

      # Hidden when the dashboard won't show its POS callout either
      def connect_pos? = OrgServices::Displayer.bike_shop_display_integration_alert?(@organization)

      def dashboard_url = organization_root_url(organization_id: @organization.to_param)

      def logo_url = image_url("kelsey/illustrations/comic-assets_logo-cape.png", host: root_url)

      def preheader = connect_pos? ? translation("preheader_connect_pos") : translation("preheader")

      def hero_body
        connect_pos? ? translation("hero_body_connect_pos", name: @organization.name) : translation("hero_body", name: @organization.name)
      end

      # The name, and whether it's live
      def pos_chips = [["Lightspeed", true], ["Ascend", true], [translation("shopify_soon"), false]]

      def dashboard_items
        [[translation("see_every_bike_lead"), translation("see_every_bike")],
          [translation("track_pos_lead"), translation("track_pos")],
          [translation("check_serials_lead"), translation("check_serials")],
          [translation("free_tools_lead"), translation("free_tools")]]
      end

      def tools
        [{color: "#715EB2", title: "Bike Book", body: translation("bike_book_body"),
          href: bikebook_url, action: translation("browse_bike_book")},
          {color: "#3397DC", title: translation("ebike_checker"), body: translation("ebike_checker_body"),
           href: ebike_rules_url, action: translation("check_your_state")}]
      end

      def stats
        total_bikes, recoveries, organizations = Counts.retrieve_many("total_bikes", "recoveries", "organizations")
        [[abbreviated(total_bikes), translation("stat_bikes")],
          [number_with_delimiter(recoveries), translation("stat_recoveries")],
          ["#{number_with_delimiter(organizations.floor(-2))}+", translation("stat_partners")]]
      end

      def abbreviated(count) = (count < 1_000_000) ? number_with_delimiter(count) : "#{Counts.in_millions(count)}M+"
    end
  end
end
