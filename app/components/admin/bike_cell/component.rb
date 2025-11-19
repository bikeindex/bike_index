# frozen_string_literal: true

module Admin::BikeCell
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(bike: nil, bike_id: nil, bike_link_path: nil, search_url: nil, render_search: nil)
      @bike = bike
      @bike_id = bike_id || bike&.id
      @bike = Bike.unscoped.find_by(id: @bike_id) if @bike.blank? && @bike_id.present?

      # Store the raw bike_link_path value (can be false, nil, or a path)
      @bike_link_path_arg = bike_link_path
      @passed_search_url = search_url
      @render_search = (bike_id.present? && render_search.nil?) ? @search_url.present? : render_search
    end

    private

    def bike_link_path
      # bike_link_path can be false to not link
      return nil if @bike_link_path_arg == false
      return @bike_link_path_arg if @bike_link_path_arg.present?
      return admin_bike_path(@bike_id) if @bike_id.present?

      nil
    end

    def search_url
      @passed_search_url || url_for(sortable_search_params.merge(search_bike_id: @bike_id))
    end

    def bike_content
      content_tag(:span) do
        concat(content_tag(:small, "📷")) if @bike.thumb_path.present?
        concat(" #{@bike.title_string}")
      end
    end
  end
end
