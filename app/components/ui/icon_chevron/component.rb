# frozen_string_literal: true

module UI
  module IconChevron
    # A down-pointing chevron (stroke SVG). Callers size and rotate it via
    # html_class, e.g. `tw:size-4` plus a rotate variant to flip it when expanded.
    class Component < ApplicationComponent
      def initialize(html_class: nil)
        @html_class = html_class
      end

      def call
        content_tag(:svg, tag.path(d: "m6 9 6 6 6-6"),
          class: @html_class,
          viewBox: "0 0 24 24",
          fill: "none",
          stroke: "currentColor",
          "stroke-width": "2.2",
          "stroke-linecap": "round",
          "stroke-linejoin": "round",
          "aria-hidden": "true")
      end
    end
  end
end
