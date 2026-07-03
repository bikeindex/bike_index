# frozen_string_literal: true

module Bikes
  module Photos
    class Component < ApplicationComponent
      def initialize(bike:, owner: false)
        @bike = bike
        @owner = owner
      end

      private

      def bike_image_url
        @bike.image_url(:large) # corrects the URL for remote images in development
      end

      def bike_image
        @bike.public_images.first
      end

      def has_photos?
        bike_image_url.present? && bike_image.present?
      end

      def photos_edit_path
        edit_bike_path(@bike, edit_template: "photos")
      end
    end
  end
end
