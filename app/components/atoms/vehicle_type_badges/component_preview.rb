# frozen_string_literal: true

module Atoms
  module VehicleTypeBadges
    # @label Vehicle type badges
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def bike
        render(Atoms::VehicleTypeBadges::Component.new(bike: ::Bike.new(cycle_type: :bike)))
      end

      def e_bike
        render(Atoms::VehicleTypeBadges::Component.new(bike: ::Bike.new(cycle_type: :bike, propulsion_type: "pedal-assist")))
      end
      # @!endgroup
    end
  end
end
