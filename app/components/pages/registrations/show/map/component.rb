# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Map
        # A MapLibre map centered on a location. Marks it with a translucent circle
        # (an approximate area) or, when point: is set, a dot at the exact spot.
        # The registrations--show--map Stimulus controller lazy-loads MapLibre GL.
        class Component < ApplicationComponent
          def initialize(latitude:, longitude:, precise: false, point: false)
            @latitude = latitude
            @longitude = longitude
            @precise = precise
            @point = point
          end

          def render?
            @latitude.present? && @longitude.present?
          end

          private

          # Non-precise coordinates are rounded to Bike::PUBLIC_COORD_LENGTH decimals,
          # so the circle has to be wide enough to hide where in that square they fell
          def radius_meters
            @precise ? 250 : 1000
          end
        end
      end
    end
  end
end
