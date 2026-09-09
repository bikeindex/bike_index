# frozen_string_literal: true

module UI
  module JsonDisplay
    class Component < ApplicationComponent
      # A cell's default cap, so one long line can't hand the JSON column half the table
      TABLE_CELL_MAX_WIDTH = 500
      private_constant :TABLE_CELL_MAX_WIDTH

      def initialize(data:, max_width: nil, small: false, skip_blank: false, no_max_height: false)
        unless max_width.nil? || max_width.is_a?(Integer) || max_width == :table_cell
          raise ArgumentError, "max_width must be an integer (for pixels) or :table_cell (to be the max width of a table cell)"
        end
        @data = data
        @table_cell = max_width == :table_cell
        @max_width = @table_cell ? TABLE_CELL_MAX_WIDTH : max_width
        @small = small
        @skip_blank = skip_blank
        @no_max_height = no_max_height
      end

      def call
        tag.div(tag.pre(tag.code(pretty_json, class: "language-json"), class: pre_class),
          class: classes, style: box_style, data: {controller: "ui--json-display"})
      end

      private

      def render? = @data.present?

      def pretty_json = JSON.pretty_generate(@skip_blank ? present_or_false(@data) : @data)

      # Show false values, just not empty or nil things
      def present_or_false(data)
        data.select { |_key, value| Binxtils::InputNormalizer.present_or_false?(value) }
      end

      def classes = ["highlightjs-json", ("highlightjs-json-cell" if @table_cell), ("tw:text-xs" if @small)].compact

      # Not an endless method: the condition would be read at definition time, where the ivar is nil
      def pre_class
        "tw:max-h-72" unless @no_max_height
      end

      # Inline, because Tailwind can't generate a class for a width it only sees at runtime
      def box_style
        "max-width: #{@max_width}px;" if @max_width.present?
      end
    end
  end
end
