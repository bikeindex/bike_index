# frozen_string_literal: true

module Search::Form
  class Component < ApplicationComponent
    def initialize(target_search_path:, target_frame:, interpreted_params:, marketplace_scope: nil,
      currency: nil, price_min_amount: nil, price_max_amount: nil, result_view: nil)
      @marketplace_scope = marketplace_scope
      @target_search_path = target_search_path
      @target_frame = target_frame
      @interpreted_params = interpreted_params
      @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
      @currency_sym = (currency || Currency.default).symbol.to_s
      @price_min_amount = price_min_amount
      @price_max_amount = price_max_amount
      @result_view = SearchResults::Container::Component.permitted_result_view(result_view)
    end

    private

    def is_marketplace?
      @marketplace_scope.present?
    end

    def render_result_view?
      is_marketplace? # only marketplace for now
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

    def render_activity_and_price_wrapper?
      render_price_field? || render_primary_activity_field?
    end

    def render_price_field?
      is_marketplace? # only on marketplace
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
  end
end
