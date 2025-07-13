# frozen_string_literal: true

module SearchResults::Container
  class Component < ApplicationComponent
    def initialize(component_class:, current_user: nil, vehicles: nil, skip_cache: false)
      @component_class = component_class
      @current_user = current_user
      @vehicles = vehicles
      @skip_cache = skip_cache
    end

    def render?
      @vehicles.present? || content.present?
    end

    private

    def container_class
      if @component_class == SearchResults::VehicleThumbnail::Component
        ""
      else
        "bike-boxes"
      end
    end
  end
end
