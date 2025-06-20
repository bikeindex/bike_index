# frozen_string_literal: true

module Search::Form
  class Component < ApplicationComponent
    def initialize(target_search_path:, target_frame:, interpreted_params:, selected_query_items_options:, marketplace_scope: nil)
      @marketplace_scope = marketplace_scope
      @target_search_path = target_search_path
      @target_frame = target_frame
      @interpreted_params = interpreted_params
      @selected_query_items_options = selected_query_items_options
    end

    private

    def kind_select_options
      kind_scope = @marketplace_scope || @interpreted_params[:stolenness]

      @interpreted_params.slice(:location, :distance).merge(kind_scope:)
    end

    def query
      @interpreted_params[:query] # might be more complicated someday
    end

    def serial_value
      @interpreted_params[:raw_serial]
    end

    def render_serial_field?
      # Always render serial unless viewing marketplace - TODO: bike versions too
      return true if @marketplace_scope.blank?

      # Render the serial field, if it was passed
      @interpreted_params[:serial].present?
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end
  end
end
