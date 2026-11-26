# frozen_string_literal: true

module Atoms
  module VehicleTypeBadges
    # A bike's type as a badge, purple and led by a ⚡ for a motorized one
    class Component < ApplicationComponent
      def initialize(bike:)
        @bike = bike
      end

      def call
        type_badge = render(UI::Badge::Component.new(text: @bike.type_titleize, color: @bike.motorized? ? :purple : :gray))
        return type_badge unless @bike.motorized?

        safe_join([render(UI::Badge::Component.new(text: "⚡", title: translation(".e_vehicle"), color: :purple)), type_badge], " ")
      end
    end
  end
end
