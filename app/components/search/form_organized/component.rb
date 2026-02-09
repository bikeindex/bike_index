# frozen_string_literal: true

module Search::FormOrganized
  class Component < ApplicationComponent
    def initialize(target_search_path:, interpreted_params:, skip_serial_field: false)
      @target_search_path = target_search_path
      @interpreted_params = interpreted_params
      @skip_serial_field = skip_serial_field
      @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
    end

    private

    def render_serial_field?
      !@skip_serial_field
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end
  end
end
