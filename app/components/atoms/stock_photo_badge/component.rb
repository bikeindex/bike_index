# frozen_string_literal: true

module Atoms
  module StockPhotoBadge
    # Marks a photo as the vehicle's model's stock photo. :word fits a thumbnail, :small a table
    # row's, and both are the trigger of a tooltip with the full description
    class Component < ApplicationComponent
      # Laid over the photo, which in dark mode is often a transparent PNG on a dark background
      CLASSES = "tw:inline-block tw:rounded-full tw:bg-gray-900/40 tw:font-bold tw:text-white tw:backdrop-blur-sm " \
        "tw:dark:bg-gray-500/60"

      DISPLAY_CLASSES = {
        full: "tw:px-2 tw:py-0.5 tw:text-xs",
        word: "tw:px-[7px] tw:text-2xs tw:leading-4",
        small: "tw:px-[3px] tw:text-[0.5rem] tw:leading-[0.625rem]"
      }.freeze

      def initialize(bike:, display: :full, html_class: nil)
        @bike = bike
        @display = DISPLAY_CLASSES.key?(display) ? display : :full
        @html_class = html_class
      end

      def render? = @bike&.stock_photo_url.present?

      def call
        tag.span(class: @html_class) do
          next pill if @display == :full

          render(UI::Tooltip::Component.new(text: description)) { pill }
        end
      end

      private

      def pill = tag.span(text, class: "#{CLASSES} #{DISPLAY_CLASSES[@display]}")

      def description
        translation(".stock_photo_of", model: [@bike.year, @bike.frame_model].compact_blank.join(" "))
      end

      def text
        (@display == :full) ? description : translation(".stock")
      end
    end
  end
end
