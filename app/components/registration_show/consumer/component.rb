# frozen_string_literal: true

module RegistrationShow
  module Consumer
    class Component < ApplicationComponent
      def initialize(bike:, current_user:, show_for_sale: false)
        @bike = bike
        @current_user = current_user
        @show_for_sale = show_for_sale
        @owner = @bike.authorized?(@current_user)
      end

      private

      def title
        @bike.name.presence || helpers.bike_title_html(@bike)
      end

      def subtitle
        parts = [@bike.year, manufacturer_name, @bike.frame_model].compact_blank
        [parts.join(" "), @bike.frame_colors.to_sentence].compact_blank.join(" · ")
      end

      def manufacturer_name
        @bike.manufacturer&.other? ? @bike.mnfg_name : @bike.manufacturer&.name
      end

      def audience_label
        @owner ? translation(".audience_owner") : translation(".audience_public")
      end

      def audience_color
        @owner ? :success : :notice
      end

      def registered_full_date
        l(@bike.created_at, format: "%B %-d, %Y")
      end

      def frame_spec
        [@bike.frame_material_name, @bike.frame_size&.upcase].compact_blank.join(" · ")
      end

      def activity_name
        @bike.primary_activity&.display_name
      end

      def primary_color_name
        @bike.frame_colors.first
      end

      def primary_color_hex
        @bike.primary_frame_color&.display
      end

      def show_marketplace_button?
        @owner && (@bike.current_marketplace_listing&.current? || @current_user&.can_create_listing?)
      end
    end
  end
end
