# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      include SortableHelper

      ARROW_UP = "\u2191"
      ARROW_DOWN = "\u2193"
      NBSP = "\u00A0"

      Column = Data.define(:label, :sortable, :block, :classes)

      # Pass cache_key to enable per-row fragment caching (e.g. cache_key: "admin-users").
      def initialize(records:, cache_key: nil, classes: nil, unbordered: false, sort: nil, sort_direction: nil)
        @records = records
        @cache_key = cache_key
        @classes = classes
        @bordered = !unbordered
        @sort = sort
        @sort_direction = sort ? (sort_direction || "desc") : sort_direction
        @columns = []
      end

      def column(label: nil, sortable: nil, classes: nil, &block)
        @columns << Column.new(label:, sortable:, block:, classes:)
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
        @sort_direction || (helpers.respond_to?(:sort_direction) ? helpers.sort_direction : nil)
      end

      def render_sortable(column)
        title = column.gsub(/_(id|at)\z/, "").titleize
        direction = (column == current_sort && current_direction == "desc") ? "asc" : "desc"
        css = "twlink"

        if column == current_sort
          css += " active"
          arrow_spans = [
            content_tag(:span, arrow_for(current_direction), class: "tw:group-hover/sort:hidden"),
            content_tag(:span, arrow_for(direction), class: "tw:hidden tw:group-hover/sort:inline tw:opacity-50")
          ]
        else
          arrow_spans = [
            content_tag(:span, arrow_for(direction), class: "tw:opacity-0 tw:group-hover/sort:opacity-50 tw:transition-opacity")
          ]
        end

        link_to(sortable_url(column, direction), class: "#{css} tw:group/sort") do
          safe_join([title, NBSP, *arrow_spans])
        end
      end

      def arrow_for(direction)
        (direction == "desc") ? ARROW_DOWN : ARROW_UP
      end

      def first_col?(index) = index == 0
      def last_col?(index) = index == @columns.length - 1

      def th_classes(col, index)
        classes = ["tw:border-0 tw:bg-gray-200 tw:px-1 tw:py-2 tw:dark:bg-gray-700"]
        if @bordered
          classes << "tw:border-b tw:border-l tw:border-t tw:border-gray-300 tw:dark:border-gray-600"
          classes << "tw:border-r" if last_col?(index)
        end
        classes << "tw:rounded-tl-sm" if first_col?(index)
        classes << "tw:rounded-tr-sm" if last_col?(index)
        classes << col.classes if col.classes
        classes.join(" ")
      end

      def td_classes(col, index, last_row:)
        classes = ["tw:border-0 tw:px-1 tw:py-1"]
        if @bordered
          classes << "tw:border-b tw:border-l tw:border-gray-200 tw:dark:border-gray-700"
          classes << "tw:border-r" if last_col?(index)
        else
          classes << "tw:border-b tw:border-gray-100 tw:dark:border-gray-700"
        end
        classes << "tw:rounded-bl-sm" if last_row && first_col?(index)
        classes << "tw:rounded-br-sm" if last_row && last_col?(index)
        classes << col.classes if col.classes
        classes.join(" ")
      end

      def sortable_url(sort, direction)
        url_for(sortable_search_params.merge(sort:, direction:))
      end

      def table_classes
        [
          "tw:min-w-full tw:text-left tw:border-separate! tw:border-spacing-0",
          @classes
        ].compact.join(" ")
      end
    end
  end
end
