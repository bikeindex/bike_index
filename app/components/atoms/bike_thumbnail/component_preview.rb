# frozen_string_literal: true

module Atoms
  module BikeThumbnail
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      def with_photo
        render(Component.new(bike: ::Bike.new(thumb_path: "https://files.bikeindex.org/uploads/Pu/395980/small_D3C6B1AF-F1FC-4BAA-BD39-9C107871FCAE.jpeg")))
      end

      def with_stock_photo
        render(Component.new(bike: ::Bike.new(year: 2025, frame_model: "Sneak Plus EQ MidStep", stock_photo_url: "https://bikebook.bikeindex.org/aventon/2022/level-2.jpg")))
      end

      def without_photo
        render(Component.new(bike: ::Bike.new))
      end
      # @!endgroup
    end
  end
end
