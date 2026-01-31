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

    def query
      @interpreted_params[:query]
    end

    def serial_value
      @interpreted_params[:raw_serial]
    end

    def search_email_value
      @interpreted_params[:search_email]
    end

    def render_serial_field?
      !@skip_serial_field
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end

    def stolenness
      @interpreted_params[:stolenness]
    end

    def search_stickers
      @interpreted_params[:search_stickers]
    end

    def search_address
      @interpreted_params[:search_address]
    end

    def search_secondary
      @interpreted_params[:search_secondary]
    end

    def search_model_audit_id
      @interpreted_params[:search_model_audit_id]
    end
  end
end
