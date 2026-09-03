# frozen_string_literal: true

module UI
  module JsonDisplay
    class Component < ApplicationComponent
      def initialize(data:, max_width: nil, small: false, skip_blank: false)
        @data = data
        @max_width = max_width
        @small = small
        @skip_blank = skip_blank
      end

      def call
        tag.div(helpers.pretty_print_json(@data, @skip_blank), class: classes, style: box_style)
      end

      private

      def render? = @data.present?

      def classes = ["twjson-box", ("tw:text-xs" if @small)].compact

      # Inline, because Tailwind can't generate a class for a width it only sees at runtime
      def box_style
        "max-width: #{@max_width}px;" if @max_width.present?
      end
    end
  end
end
