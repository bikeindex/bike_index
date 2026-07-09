# frozen_string_literal: true

module UI
  module ColorSwatch
    # A small square showing a bike color. The display-less "cover-up" color
    # renders Color::COVER_UP_SWATCH's multicolor blend instead of a solid fill.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-block tw:h-6 tw:w-6 tw:rounded-xs tw:border tw:border-black/20 tw:align-middle"

      def initialize(display: nil, name: nil)
        @display = display.presence
        @name = name.presence
      end

      def call
        content_tag(:span, "", class: BASE_CLASSES, style: swatch_style, title: @name)
      end

      private

      def cover_up?
        @name == Color::COVER_UP_NAME
      end

      def swatch_style
        "background: #{cover_up? ? Color::COVER_UP_SWATCH : @display}"
      end
    end
  end
end
