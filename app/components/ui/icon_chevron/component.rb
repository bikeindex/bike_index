# frozen_string_literal: true

module UI
  module IconChevron
    class Component < ApplicationComponent
      ROTATIONS = {
        right: nil,
        down: "tw:rotate-90",
        left: "tw:rotate-180",
        up: "tw:rotate-270"
      }.freeze

      SIZES = {
        sm: "tw:h-3 tw:w-3",
        md: "tw:h-4 tw:w-4"
      }.freeze

      def initialize(direction: :right, size: :sm, html_class: nil)
        @direction = ROTATIONS.key?(direction) ? direction : :right
        @size = SIZES.key?(size) ? size : :sm
        @html_class = html_class
      end

      def call
        helpers.inline_svg_tag("icons/chevron-right.svg",
          class: ["tw:inline-block", SIZES[@size], ROTATIONS[@direction], @html_class].compact.join(" "))
      end
    end
  end
end
