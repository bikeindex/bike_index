# frozen_string_literal: true

module Atoms
  module BikeThumbnail
    # A table-row-sized bike photo, or a blank tile the same size when there's none
    class Component < ApplicationComponent
      CLASSES = "tw:block tw:h-8 tw:w-11 tw:rounded-lg tw:border tw:border-gray-200 tw:dark:border-gray-700"

      def initialize(bike:)
        @url = bike && BikeServices::Displayer.thumb_image_url(bike)
      end

      def call
        if @url.present?
          image_tag(@url, alt: "", loading: "lazy", skip_pipeline: true, class: "#{CLASSES} tw:object-cover")
        else
          tag.span(class: "#{CLASSES} tw:bg-gray-100 tw:dark:bg-gray-800")
        end
      end
    end
  end
end
