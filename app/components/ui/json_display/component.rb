# frozen_string_literal: true

module UI
  module JsonDisplay
    class Component < ApplicationComponent
      # A cell's default cap, so one long line can't hand the JSON column half the table
      TABLE_CELL_MAX_WIDTH = 500

      def initialize(data:, max_width: nil, small: false, skip_blank: false, table_cell: false)
        @data = data
        @max_width = max_width || (TABLE_CELL_MAX_WIDTH if table_cell)
        @small = small
        @skip_blank = skip_blank
        @table_cell = table_cell
      end

      def call
        tag.div(tag.pre(tag.code(pretty_json, class: "language-json")),
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

      # Inline, because Tailwind can't generate a class for a width it only sees at runtime
      def box_style
        "max-width: #{@max_width}px;" if @max_width.present?
      end
    end
  end
end
