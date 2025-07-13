# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class Component < ApplicationComponent
    def initialize(bike:, current_user: nil, current_event_record: nil, skip_cache: false)
      @bike = bike
      return if @bike.blank?

      @current_event_record ||= @bike.current_event_record

      @is_cached = !skip_cache
    end
  end
end
