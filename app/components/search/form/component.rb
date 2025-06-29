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

    def is_marketplace?
      @marketplace_scope.present?
    end

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
      return true unless is_marketplace?

      # Render the serial field, if it was passed
      @interpreted_params[:serial].present?
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end

    def render_primary_activity_field?
      return true if is_marketplace? # Also show on bike versions

      # Render the primary_activity field, if it was passed
      @interpreted_params[:primary_activity].present?
    end

    def primary_activity_select_opts
      options_for_select(
        PrimaryActivity.by_priority.map { |pa| [pa.display_name_search, pa.id] },
        selected: @interpreted_params[:primary_activity]
      )
    end

    def primary_activity_prompt
      if @interpreted_params[:primary_activity].present?
        translation(".any_primary_activity")
      else
        translation(".search_for_primary_activity")
      end
    end
  end
end
