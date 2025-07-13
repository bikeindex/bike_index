# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class Component < ApplicationComponent
    include BikeHelper

    def initialize(bike:, current_user: nil, current_event_record: nil, skip_cache: false)
      @bike = bike
      return if @bike.blank?

      @current_event_record ||= @bike.current_event_record

      @is_cached = !skip_cache
      # current_user is ignored, but included to match other SearchResults
    end

    def render?
      @bike.present?
    end
  end
end
