# frozen_string_literal: true

module PageBlock
  module Resources
    class Component < ApplicationComponent
      def initialize(current_user: nil)
        @current_user = current_user
      end

      private

      def bike_tile_images
        (0..16).map { it.to_s.rjust(2, "0") }
          .map { image_url("kelsey/bike_tiles/bike-entry_00#{it}.png") }
      end

      def design_resources
        [
          {thumbnail: "kelsey/resources/logos.png", title: "Downloadable Logos", description: "All versions of the Bike Index shield logo as SVG and PNG files.", button_text: "Download Logo Pack", file: "/resources/bike-index-logo-pack.zip"},
          {thumbnail: "kelsey/resources/flyer.png", title: "Bulletin Board Flyer", description: "A printable 8.5x11\" flyer for your bulletin board! Has space to customize with your city, university, or community group.", button_text: "Download Flyer", file: "/resources/printable-flyer.jpg"},
          {thumbnail: "kelsey/resources/brochure.png", title: "Trifold Brochure", description: "A printable 8.5x11\" sheet you can fold into 3 panels. Print in full color and double-sided.", button_text: "Download Brochure", file: "/resources/bike-index-trifold.pdf"},
          {thumbnail: "kelsey/resources/shop-card.png", title: "Bike Shop Card", description: "Design is for notecard size (5.5\" x 4.25\").", button_text: "Download Shop Card", file: "/resources/bike-index-shop-card.pdf"},
          {thumbnail: "kelsey/resources/cool-bike-check.png", title: "Cool Bike Check", description: "Printable sheet with 4 Cool Bike Check tags.", button_text: "Download Tags", file: "/resources/cool-bike-check.pdf"},
          {thumbnail: "kelsey/resources/graphics-pack.png", title: "Graphics Pack", description: "Complete collection of illustrated graphics and visual assets for your projects and presentations.", button_text: "Download Graphics Pack", file: "/resources/graphics-pack.zip"}
        ]
      end

      def dev_resources
        [
          {title: "Bike Index on GitHub", description: "Bike Index itself is open source — check it out on GitHub.", link_text: "View on GitHub", url: "https://github.com/bikeindex/bike_index", external: true},
          {title: "API Documentation", description: "Complete documentation for the Bike Index API.", link_text: "View API Docs", url: documentation_index_path},
          {title: "Nearby Stolen Widget", description: "Display nearby stolen bikes on your website.", link_text: "View Widget on GitHub", url: "https://github.com/bikeindex/stolen_bike_widget", external: true},
          {title: "Personal Bike Display Widget", description: "Show your registered bikes on your personal website (requires login — also, has no usage instructions...).", link_text: "Get Widget Code", url: widget_url},
          {title: "OAuth Applications You've Made", description: "Manage OAuth applications you've created (requires login).", link_text: "Manage Applications", url: oauth_applications_path},
          {title: "OAuth Applications You've Authorized", description: "View and manage OAuth applications you've authorized (requires login).", link_text: "View Authorized Apps", url: oauth_authorized_applications_path}
        ]
      end

      def widget_url
        @current_user ? user_embed_path(@current_user) : new_user_path(return_to: resources_path)
      end
    end
  end
end
