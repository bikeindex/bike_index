# frozen_string_literal: true

module Atoms
  module StockPhotoBadge
    class ComponentPreview < ApplicationComponentPreview
      # @!group Displays
      def full
        render(Component.new(bike:))
      end

      def word
        render(Component.new(bike:, display: :word))
      end

      def small
        render(Component.new(bike:, display: :small))
      end
      # @!endgroup

      private

      def bike
        ::Bike.new(year: 2025, frame_model: "Sneak Plus EQ MidStep", stock_photo_url: "https://bikebook.bikeindex.org/aventon/2022/level-2.jpg")
      end
    end
  end
end
