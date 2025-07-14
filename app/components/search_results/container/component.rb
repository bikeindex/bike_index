# frozen_string_literal: true

module SearchResults::Container
  class Component < ApplicationComponent
    def initialize(kind:, current_user: nil, vehicles: nil, skip_cache: false)
      @component_class = component_class_for_kind(kind&.to_sym)
      @current_user = current_user
      @vehicles = vehicles
      @skip_cache = skip_cache
    end

    def render?
      @vehicles.present? || content.present?
    end

    private

    def component_class_for_kind(kind)
      if kind == :thumbnail
        SearchResults::VehicleThumbnail::Component
      else
        SearchResults::BikeBox::Component
      end
    end

    def container_class
      if @component_class == SearchResults::VehicleThumbnail::Component
        ""
      else
        "bike-boxes"
      end
    end
  end
end
