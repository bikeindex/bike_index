# frozen_string_literal: true

module RegistrationShow
  module Consumer
    class Component < ApplicationComponent
      # owner: overrides the computed ownership so the wrapper can force the
      # public or owner perspective (view_as)
      def initialize(bike:, current_user:, show_for_sale: false, mapbox_key: nil, owner: nil)
        @bike = bike
        @current_user = current_user
        @show_for_sale = show_for_sale
        @mapbox_key = mapbox_key
        @owner = owner.nil? ? (@current_user.present? && @bike.owner == @current_user) : owner
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
        return translation(".audience_owner") if @owner
        return translation(".audience_sent_away") if previously_owned?

        translation(".audience_public")
      end

      def audience_color
        return :success if @owner
        return :warning if previously_owned?

        :notice
      end

      # The current user held an ownership that's no longer current (bike sent away)
      def previously_owned?
        return false if @owner || @current_user.blank?

        @bike.ownerships.where(user_id: @current_user.id, current: false).exists?
      end

      def status_label
        @bike.status_stolen? ? translation(".stolen") : translation(".not_stolen")
      end

      def status_color
        @bike.status_stolen? ? :error : :success
      end

      def status_text_class
        @bike.status_stolen? ? "tw:text-red-600" : "tw:text-green-600"
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
        @owner && @bike.status_with_owner? &&
          (@bike.current_marketplace_listing&.current? || @current_user&.can_create_listing?)
      end
    end
  end
end
