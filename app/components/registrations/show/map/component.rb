# frozen_string_literal: true

module Registrations
  module Show
    module Map
      # A Mapbox map centered on a location. Marks it with a translucent circle
      # (an approximate area) or, when point: is set, a dot at the exact spot.
      # The registrations--show--map Stimulus controller lazy-loads Mapbox GL.
      class Component < ApplicationComponent
        MAPBOX_KEY = ENV["MAPBOX_MAPPING"]

        def initialize(latitude:, longitude:, precise: false, point: false)
          @latitude = latitude
          @longitude = longitude
          @precise = precise
          @point = point
        end

        def render?
          @latitude.present? && @longitude.present? && MAPBOX_KEY.present?
        end

        private

        # The circle grows faster with zoom when the exact address is public
        def radius_base
          @precise ? 2 : 1.15
        end
      end
    end
  end
end
