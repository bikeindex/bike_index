# frozen_string_literal: true

module RegistrationShow
  module Map
    # A Mapbox map centered on a location, with a translucent circle marking it.
    # The registration-show--map Stimulus controller lazy-loads Mapbox GL.
    class Component < ApplicationComponent
      def initialize(latitude:, longitude:, mapbox_key:, precise: false)
        @latitude = latitude
        @longitude = longitude
        @mapbox_key = mapbox_key
        @precise = precise
      end

      def render?
        @latitude.present? && @longitude.present? && @mapbox_key.present?
      end

      private

      # The circle grows faster with zoom when the exact address is public
      def radius_base
        @precise ? 2 : 1.15
      end
    end
  end
end
