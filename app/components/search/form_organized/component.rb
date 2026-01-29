# frozen_string_literal: true

module Search::FormOrganized
  class Component < ApplicationComponent
    def initialize(target_search_path:, target_frame:, interpreted_params:, skip_serial_field:, result_view:)
      @target_search_path = target_search_path
    @target_frame = target_frame
    @interpreted_params = interpreted_params
    @skip_serial_field = skip_serial_field
    @result_view = result_view
    end
  end
end
