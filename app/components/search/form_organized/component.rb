# frozen_string_literal: true

module Search::FormOrganized
  class Component < ApplicationComponent
    def initialize(target_search_path:, interpreted_params:, target_frame: nil, skip_serial_field: false, settings_component: nil, turbo_stream: false)
      @target_search_path = target_search_path
      @interpreted_params = interpreted_params
      @target_frame = target_frame
      @skip_serial_field = skip_serial_field
      @settings_component = settings_component
      @turbo_stream = turbo_stream
      @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
    end

    private

    def turbo?
      @target_frame.present?
    end

    def form_data
      if turbo?
        data = {:turbo_action => "advance",
                :turbo => true, "search--form-target" => "form"}
        data[:turbo_frame] = @target_frame unless @turbo_stream
        data[:turbo_stream] = true if @turbo_stream
        data
      else
        {turbo: false}
      end
    end

    def render_serial_field?
      !@skip_serial_field
    end

    def serial_looks_like_not_a_serial?
      @interpreted_params[:raw_serial].present? && @interpreted_params[:serial].blank?
    end

    def render_notes_field?
      @settings_component&.organization&.enabled?("registration_notes")
    end
  end
end
