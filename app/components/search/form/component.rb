# frozen_string_literal: true

module Search::Form
  class Component < ApplicationComponent
    def initialize(target_search_path:, target_frame:, interpreted_params:, selected_query_items_options:, is_marketplace: false)
      @is_marketplace = is_marketplace
      @target_search_path = target_search_path
      @target_frame = target_frame
      @interpreted_params = interpreted_params
      @selected_query_items_options = selected_query_items_options
    end

    private

    def kind_select_options
      @interpreted_params.slice(:stolenness, :location, :distance)
        .merge(is_marketplace: @is_marketplace)
    end

    def query
      @interpreted_params[:query] # might be more complicated someday
    end

    def serial_value
      @interpreted_params[:raw_serial]
    end

    def render_serial_field?
      !@is_marketplace # false if bike versions, or marketplace
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end
  end
end
