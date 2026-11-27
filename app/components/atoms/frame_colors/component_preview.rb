# frozen_string_literal: true

module Atoms
  module FrameColors
    # @label Frame colors
    class ComponentPreview < ApplicationComponentPreview
      def default
        bike = ::Bike.new(primary_frame_color: ::Color.new(name: "Black", display: "#000"),
          secondary_frame_color: ::Color.new(name: "Blue", display: "#386ed2"))
        render(Atoms::FrameColors::Component.new(bike:))
      end
    end
  end
end
