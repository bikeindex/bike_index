# frozen_string_literal: true

module Admin::BikeCell
  class Component < ApplicationComponent
    def initialize(bike: nil, bike_id: nil, bike_link_path: nil, search_url: nil, render_search: nil)
      @bike = bike
      @bike_id = bike_id || bike&.id
      @bike = Bike.unscoped.find_by(id: @bike_id) if @bike.blank? && @bike_id.present?

      # Store the raw bike_link_path value (can be false, nil, or a path)
      @bike_link_path_arg = bike_link_path
      @search_url = search_url
      @render_search = render_search.nil? ? @search_url.present? : render_search
    end

    def bike_link_path
      # bike_link_path can be false to not link
      return nil if @bike_link_path_arg == false
      return @bike_link_path_arg if @bike_link_path_arg.present?
      return admin_bike_path(@bike_id) if @bike_id.present?

      nil
    end
  end
end
