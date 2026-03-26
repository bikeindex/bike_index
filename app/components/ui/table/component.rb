# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      Column = Data.define(:label, :sortable, :block)

      # Pass cache_key to enable per-row fragment caching (e.g. cache_key: "admin-users").
      def initialize(records:, cache_key: nil, classes: nil, sort: nil, sort_direction: nil)
        @records = records
        @cache_key = cache_key
        @classes = classes
        @sort = sort
        @sort_direction = sort_direction || "desc"
        @columns = []
      end

      def with_column(label: nil, sortable: nil, &block)
        @columns << Column.new(label:, sortable:, block:)
        nil
      end

      def before_render
        content
      end

      private

      def current_sort
        @sort || (helpers.respond_to?(:sort_column) ? helpers.sort_column : nil)
      end

      def current_direction
        @sort_direction || (helpers.respond_to?(:sort_direction) ? helpers.sort_direction : "desc")
      end

      def render_sortable(column)
        title = column.gsub(/_(id|at)\z/, "").titleize
        direction = (column == current_sort && current_direction == "desc") ? "asc" : "desc"
        css = "link sortable-link"

        if column == current_sort
          css += " link-active"
          arrow = (current_direction == "desc") ? "\u2193" : "\u2191"
          arrow_class = "sortable-direction"
        else
          arrow = (direction == "desc") ? "\u2193" : "\u2191"
          arrow_class = "sortable-direction opacity-0 group-hover:opacity-50 transition-opacity"
        end

        helpers.link_to(helpers.sortable_url(column, direction), class: "#{css} group") do
          helpers.safe_join([title, "\u00A0", helpers.content_tag(:span, arrow, class: arrow_class)])
        end
      end

      def table_classes
        [
          "min-w-full text-sm text-left text-gray-500 dark:text-gray-400",
          @classes
        ].compact.join(" ")
      end
    end
  end
end
