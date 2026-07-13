# frozen_string_literal: true

module UI
  module ColorSwatch
    # A small square showing a bike color. The display-less "cover-up" color
    # renders Color::COVER_UP_SWATCH's multicolor blend instead of a solid fill.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:inline-block tw:rounded-xs tw:border tw:border-black/20"

      SIZES = {sm: "tw:h-3 tw:w-3", md: "tw:h-6 tw:w-6"}.freeze

      ALIGNS = {middle: "tw:align-middle", baseline: "tw:align-baseline"}.freeze

      def initialize(display: nil, name: nil, size: :md, align: :middle)
        @display = display.presence
        @name = name.presence
        @size = SIZES.key?(size) ? size : :md
        @align = ALIGNS.key?(align) ? align : :middle
      end

      def call
        content_tag(:span, "", class: "#{BASE_CLASSES} #{SIZES[@size]} #{ALIGNS[@align]}", style: swatch_style, title: @name)
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
