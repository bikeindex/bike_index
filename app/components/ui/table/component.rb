# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      include SortableHelper

      ARROW_UP = "\u2191"
      ARROW_DOWN = "\u2193"
      NBSP = "\u00A0"

      Column = Data.define(:label, :sortable, :block, :classes, :lower_right)

      # Pass cache_key to enable per-row fragment caching (e.g. cache_key: "admin-users").
      def initialize(records:, cache_key: nil, classes: nil, unbordered: false, sort: nil, sort_direction: nil, render_sortable: false)
        @records = records
        @cache_key = cache_key
        @classes = classes
        @bordered = !unbordered
        @sort = sort
        @sort_direction = sort ? (sort_direction || "desc") : sort_direction
        @render_sortable = render_sortable
        @columns = []
      end

      def column(label: nil, sortable: nil, classes: nil, lower_right: nil, &block)
        @columns << Column.new(label:, sortable:, block:, classes:, lower_right:)
        nil
      end

      def before_render
        content
      end

      private

      def current_sort
        @current_sort ||= @sort || helper_sort_column || default_sort_column
      end

      def current_direction
        @sort_direction || (helpers.respond_to?(:sort_direction) ? helpers.sort_direction : nil) || "desc"
      end

      def helper_sort_column
        return unless helpers.respond_to?(:sort_column)
        col = helpers.sort_column
        sortable_columns.include?(col) ? col : nil
      end

      def default_sort_column
        @columns.find { |c| c.sortable }&.sortable
      end

      def sortable_columns
        @columns.filter_map(&:sortable)
      end

      def render_sortable(column, label = nil)
        title = label || column.gsub(/_(id|at)\z/, "").titleize
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

      def render_header(col)
        (col.sortable.present? && @render_sortable) ? render_sortable(col.sortable, col.label) : (col.label || col.sortable&.gsub(/_(id|at)\z/, "")&.titleize)
      end

      def render_cell(col, record)
        cell_content = capture { instance_exec(record, &col.block) }
        return cell_content unless col.lower_right

        lower_right_content = instance_exec(record, &col.lower_right)
        content_tag(:div, class: "tw:relative tw:min-h-5") do
          safe_join([
            cell_content,
            content_tag(:small, safe_join([NBSP.html_safe, lower_right_content]),
              class: "tw:absolute tw:-right-0.5 tw:-bottom-1 tw:text-xs tw:text-gray-400")
          ])
        end
      end

      def arrow_for(direction)
        (direction == "desc") ? ARROW_DOWN : ARROW_UP
      end

      def last_row?(row_index) = row_index == @records.length - 1
      def first_col?(index) = index == 0
      def last_col?(index) = index == @columns.length - 1

      def th_classes(col, index)
        classes = ["tw:border-0 tw:bg-gray-200 tw:px-1 tw:py-2 tw:dark:bg-gray-700"]
        if @bordered
          classes << "tw:border-b tw:border-r tw:border-t tw:border-gray-300 tw:dark:border-gray-600"
          classes << "tw:border-l" if first_col?(index)
        end
        classes << "tw:rounded-tl-sm" if first_col?(index)
        classes << "tw:rounded-tr-sm" if last_col?(index)
        classes << col.classes if col.classes
        classes.join(" ")
      end

      def td_classes(col, index, last_row:)
        classes = ["tw:border-0 tw:px-1 tw:py-1"]
        if @bordered
          classes << "tw:border-b tw:border-r tw:border-gray-200 tw:dark:border-gray-700"
          classes << "tw:border-l" if first_col?(index)
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
