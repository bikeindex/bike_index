# frozen_string_literal: true

module Search::Form
  class Component < ApplicationComponent
    def initialize(distance:, include_location_search:, search_path:, interpreted_params:, skip_serial_field:)
      @distance = distance
    @include_location_search = include_location_search
    @search_path = search_path
    @interpreted_params = interpreted_params
    @skip_serial_field = skip_serial_field
    end
  end
end
