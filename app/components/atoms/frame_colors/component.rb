# frozen_string_literal: true

module Atoms
  module FrameColors
    # A swatch per frame color, then their names
    class Component < ApplicationComponent
      def initialize(bike:, html_class: nil)
        @bike = bike
        @html_class = html_class
      end

      def render?
        @bike.frame_color_records.any?
      end

      def call
        swatches = @bike.frame_color_records.map do |color|
          render(UI::ColorSwatch::Component.new(display: color.display, name: color.name, size: :sm))
        end

        content_tag(:span, class: ["tw:flex tw:items-center tw:gap-1.5", @html_class]) do
          safe_join([content_tag(:span, safe_join(swatches), class: "tw:flex tw:gap-0.5"), @bike.frame_colors.join(" / ")], " ")
        end
      end
    end
  end
end
