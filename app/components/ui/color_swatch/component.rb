# frozen_string_literal: true

module UI
  module ColorSwatch
    # A small square showing a bike color. The display-less "cover-up" color
    # renders Color::COVER_UP_SWATCH's multicolor blend instead of a solid fill.
    #
    # Decorative: every caller prints the color name beside the swatch, so giving the
    # swatch an accessible name of its own would announce "Red Red".
    class Component < ApplicationComponent
      # leading-[0] collapses the empty box's line-height strut so align-baseline
      # sits its bottom on the text baseline instead of floating above it
      BASE_CLASSES = "tw:inline-block tw:leading-[0] tw:rounded-xs tw:border tw:border-black/20"

      SIZES = {sm: "tw:h-3 tw:w-3", md: "tw:h-6 tw:w-6"}.freeze

      ALIGNS = {middle: "tw:align-middle", baseline: "tw:align-baseline"}.freeze

      def initialize(display: nil, name: nil, size: :md, align: :middle)
        @display = display.presence
        @name = name.presence
        @size = SIZES.key?(size) ? size : :md
        @align = ALIGNS.key?(align) ? align : :middle
      end

      def call
        content_tag(:span, "", class: "#{BASE_CLASSES} #{SIZES[@size]} #{ALIGNS[@align]}", style: swatch_style, aria: {hidden: true})
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
