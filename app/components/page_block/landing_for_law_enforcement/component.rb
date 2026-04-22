# frozen_string_literal: true

module PageBlock
  module LandingForLawEnforcement
    class Component < ApplicationComponent
      include MoneyHelper

      PARTNER_CITIES = %w[Calgary Edmonton Lethbridge Bend Portland Sunnyvale Davis].freeze

      TOOLS = [
        {key: "leadsonline", image: "features_0001_leadsonline.png", title: "LeadsOnline Integration",
         description: "Theft victims add their police report number, entering bikes into LEADS so pawn shops can flag stolen property."},
        {key: "hot-sheet", image: "features_0005_daily-hot-sheet.png", title: "Daily Hot Sheet",
         description: "Local stolen bike reports delivered to your inbox every morning with complete details and photos."},
        {key: "dashboard", image: "features_0008_dashboard-analytics.png", title: "Dashboard Analytics",
         description: "Filter bikes by time and status to track trends and identify where recovery efforts are most effective."},
        {key: "direct-contact", image: "features_0009_direct-communication.png", title: "Direct Contact with Owners",
         description: "Message bike owners directly via phone or email for abandoned bikes and recovered property with logged communications."},
        {key: "export", image: "features_0007_data-export.png", title: "Data Export",
         description: "Export and share registration and recovery data with leadership to demonstrate program impact and success."},
        {key: "impound", image: "features_0002_impound-lot.png", title: "Impound Lot Management",
         description: "Upload and search impound lot bikes, automatically notify owners, and manage ownership claims through the platform."},
        {key: "credibility", image: "features_0004_credibility-badges.png", title: "Credibility Badges",
         description: "Owner credibility scores based on account age, registration source, and history help identify legitimate claims."},
        {key: "pos", image: "features_0000_POS.png", title: "POS Integration",
         description: "Local bike shops automatically register every bike they sell directly into your law enforcement dashboard system."},
        {key: "social-alerts", image: "features_0003_social-media-alerts.png", title: "Social Media Alerts",
         description: "Automatic social media posts on Twitter, Facebook, and Instagram reach bike-sympathetic community members who can help."},
        {key: "qr-stickers", image: "features_0006_qr-stickers.png", title: "QR Stickers",
         description: "Tamper-proof stickers break apart when removed and provide instant owner lookup for recovered bikes in the field."}
      ].freeze

      FEATURES = [
        {image: "assets-law_1.png", title: "Law Enforcement Dashboard",
         description: "See registration efforts in real-time. Track regional metrics, filter by time period, and export data to share results up the chain of command."},
        {image: "assets-law_2.png", title: "Investigative Resources",
         description: "QR stickers, LeadsOnline integration, daily stolen bike hot sheets, and credibility badges help you identify bad actors and verify ownership."},
        {image: "assets-law_3.png", title: "Community Recovery",
         description: "Our network of ambassadors and social media tools turn your community into allies. Automatic theft alerts on Twitter, Facebook, and Instagram."}
      ].freeze

      TESTIMONIALS = [
        {quote: "We're going to find a lot more stolen bikes quicker and hope to alleviate the bike thefts that are happening.",
         author: "Cst. Shawn Davis", org: "LPS"},
        {quote: "With Calgarians already registering almost 9,000 bikes and further building Bike Index's database, Calgary's recovery number is already climbing.",
         author: "Cst. Dan Seibel", org: "CPS"},
        {quote: "We are very excited to partner with Bike Index, as this partnership symbolizes a joint effort in returning countless numbers of bicycles to their rightful owners.",
         author: "Officer Brittany Elenes", org: "LAPD"}
      ].freeze

      def initialize(feedback: Feedback.new, current_user: nil)
        @feedback = feedback
        @current_user = current_user
      end

      private

      def recoveries_value_display
        as_currency(Counts.recoveries_value / 1_000_000) + "M+"
      end

      def recoveries_display
        number_with_delimiter(Counts.recoveries)
      end

      def organizations_display
        number_with_delimiter(Counts.organizations)
      end

      def bike_tile_images
        (0..16).map { it.to_s.rjust(2, "0") }
          .map { image_url("kelsey/bike_tiles/bike-entry_00#{it}.png") }
      end

      def partner_logos
        PARTNER_CITIES.map do |city|
          {name: city, image: image_url("kelsey/lawpartners/#{city}.png")}
        end + [
          {name: "Boise City", image: image_url("kelsey/lawpartners/Boise City.png")},
          {name: "Los Angeles", image: image_url("kelsey/lawpartners/LA.png")}
        ]
      end
    end
  end
end
