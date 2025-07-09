# frozen_string_literal: true

module Search::VehicleThumbnail
  class Component < ApplicationComponent
    def initialize(vehicle:, current_event_record:, skip_cache:)
      @vehicle = vehicle
    @current_event_record = current_event_record
    @skip_cache = skip_cache
    end
  end
end
