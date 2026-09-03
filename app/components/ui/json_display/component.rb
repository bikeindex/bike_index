# frozen_string_literal: true

module UI
  module JsonDisplay
    # Syntax-highlighted JSON in a scrollable box
    class Component < ApplicationComponent
      def initialize(data:, max_width: nil, small: false)
        @data = data
        @max_width = max_width
        @small = small
      end

      def call
        tag.div(highlighted_json, class: classes, style: box_style)
      end

      private

      def render? = @data.present?

      def highlighted_json
        CodeRay.scan(JSON.pretty_generate(@data), :json).div.html_safe
      end

      def classes = ["twjson-box", ("tw:text-xs" if @small)].compact

      # Inline, because Tailwind only generates the arbitrary values it can scan for
      def box_style
        return if @max_width.blank?

        "max-width: #{@max_width.is_a?(Numeric) ? "#{@max_width}px" : @max_width};"
      end
    end
  end
end
