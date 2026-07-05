# frozen_string_literal: true

module RegistrationShow
  module Photos
    class Component < ApplicationComponent
      def initialize(bike:, owner: false, title: nil, subtitle: nil)
        @bike = bike
        @owner = owner
        @title = title
        @subtitle = subtitle
      end

      private

      # Title/subtitle laid over a bottom gradient on the hero photo (mobile only -
      # on desktop the title lives in the summary column)
      def hero_overlay
        return if @title.blank?

        parts = [content_tag(:h2, @title, class: "tw:text-xl tw:font-bold tw:text-white tw:leading-tight")]
        parts << content_tag(:p, @subtitle, class: "tw:mt-0.5 tw:text-sm tw:text-white/85") if @subtitle.present?

        content_tag(:div, safe_join(parts), class: "tw:pointer-events-none tw:absolute tw:inset-x-0 tw:bottom-0 tw:bg-gradient-to-t tw:from-black/60 tw:to-transparent tw:p-4 tw:lg:hidden")
      end

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
