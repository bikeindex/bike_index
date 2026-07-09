# frozen_string_literal: true

module RegistrationShow
  module Consumer
    class Component < ApplicationComponent
      # owner: overrides the computed ownership so the wrapper can force the
      # public or owner perspective (view_as)
      def initialize(bike:, current_user:, show_for_sale: false, mapbox_key: nil, owner: nil, available_views: [])
        @bike = bike
        @current_user = current_user
        @show_for_sale = show_for_sale
        @mapbox_key = mapbox_key
        @available_views = available_views
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

      # Only vehicles that aren't a standard bike surface the type
      def vehicle_type
        @bike.cycle_type_name unless @bike.type == "bike"
      end

      def audience_label
        return translation(".audience_owner", bike_type: @bike.type) if @owner
        return translation(".audience_sent_away", bike_type: @bike.type) if previously_owned?

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

      def activity_name
        @bike.primary_activity&.display_name
      end

      def primary_colors_label
        frame_color_records.many? ? translation(".primary_colors") : translation(".primary_color")
      end

      def frame_color_records
        [@bike.primary_frame_color, @bike.secondary_frame_color, @bike.tertiary_frame_color].compact
      end

      # Each color as its own swatch + name, kept together so only the "and" wraps
      def color_swatches
        frame_color_records.map do |color|
          swatch = render(UI::ColorSwatch::Component.new(display: color.display, name: color.name, size: :sm))
          content_tag(:span, safe_join([swatch, " ", color.name]), class: "tw:whitespace-nowrap")
        end
      end

      def show_marketplace_button?
        @owner && @bike.status_with_owner? &&
          (@bike.current_marketplace_listing&.current? || @current_user&.can_create_listing?)
      end
    end
  end
end
