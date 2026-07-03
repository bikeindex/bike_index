# frozen_string_literal: true

module PageBlock
  module BikeShowRedesign
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

      def registered_since_month_year
        l(@bike.created_at, format: "%B %Y")
      end

      def registered_full_date
        l(@bike.created_at, format: "%B %-d, %Y")
      end

      def visibility_label
        @bike.user_hidden ? translation(".visibility_private") : translation(".visibility_public")
      end

      def sticker_code
        @bike.bike_stickers.first&.pretty_code
      end

      def show_marketplace_button?
        @owner && (@bike.current_marketplace_listing&.current? || @current_user&.can_create_listing?)
      end

      def cgroups_with_components
        components = @bike.components
        return [] unless components.any?

        Cgroup.commonness.filter_map do |cgroup|
          cgroup_components = components.select { |c| c.cgroup_id == cgroup.id }
          [cgroup, cgroup_components] if cgroup_components.any?
        end
      end

      def component_label(component)
        label = if component.front && component.rear
          translation(".front_rear")
        elsif component.front
          translation(".front")
        elsif component.rear
          translation(".rear")
        else
          ""
        end
        return "#{label}#{translation(".other")}" if component.component_type == "unknown"
        return label if component.component_type.blank?

        [label.presence, component.component_type.titleize].compact_blank.join(" ")
      end

      def component_value(component)
        value = [component.description, component.component_model].compact_blank
        value << translation(".componentyear", componentyear: component.year) if component.year.present?
        value << "(#{component.mnfg_name})" if component.mnfg_name.present?
        value.presence&.join(" ") || translation(".component_no_info")
      end
    end
  end
end
