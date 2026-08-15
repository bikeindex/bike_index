# frozen_string_literal: true

module Admin
  module BikeCell
    class Component < ApplicationComponent
      def initialize(
        bike: nil,
        bike_id: nil,
        bike_link_path: nil,
        search_url: nil,
        sortable_search_params: nil,
        render_search: true,
        skip_status: false
      )
        @bike = bike
        @bike_id = bike_id || bike&.id
        @bike = Bike.unscoped.find_by(id: @bike_id) if @bike.blank? && @bike_id.present?

        # Store the raw bike_link_path value (can be false, nil, or a path)
        @bike_link_path_arg = bike_link_path
        @search_url = search_url
        @sortable_search_params = sortable_search_params
        @render_search = render_search
        @skip_status = skip_status
      end

      def render?
        @bike.present? || @bike_id.present?
      end

      private

      def bike_link_path
        # bike_link_path can be false to not link
        return nil if @bike_link_path_arg == false
        return @bike_link_path_arg if @bike_link_path_arg.present?
        if @bike_id.present?
          return @bike&.version? ? admin_bike_version_path(@bike_id) : admin_bike_path(@bike_id)
        end

        nil
      end

      def computed_search_url
        return @computed_search_url if defined?(@computed_search_url)
        return @computed_search_url = @search_url if @search_url.present?

        @computed_search_url = if @sortable_search_params.present?
          url_for(@sortable_search_params.merge(search_bike_id: @bike_id))
        end
      end

      def bike_content
        content_tag(:span) do
          concat(content_tag(:small, "📷 ")) if @bike.thumb_path.present?
          concat(@bike.frame_colors.to_sentence)
          concat(" ")
          concat(content_tag(:strong, @bike.mnfg_name))
          if @bike.frame_model.present?
            concat(" ")
            concat(content_tag(:em, @bike.frame_model_truncated))
          end
          concat(content_tag(:small, " #{@bike.type}")) unless @bike.cycle_type == "bike"
          if @bike.version?
            concat(" ")
            concat(render(UI::Badge::Component.new(text: "V", title: "Bike Version", color: :purple, size: :sm)))
          elsif @bike.unregistered_parking_notification?
            concat(content_tag(:em, " unregistered", class: "small text-warning"))
          elsif @bike.creation_description.present?
            concat(", ")
            concat(content_tag(:small, render(Org::OriginDisplay::Component.new(creation_description: @bike.creation_description)), class: "less-strong"))
          end
        end
      end
    end
  end
end
