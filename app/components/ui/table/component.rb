# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      include SortableHelper

      # Pass cache_key to enable per-row fragment caching (e.g. cache_key: "admin-users").
      def initialize(records:, cache_key: nil, classes: nil, unbordered: false, sort: nil, sort_direction: nil, render_sortable: false, sticky: false)
        @records = records
        @cache_key = cache_key
        @classes = classes
        @bordered = !unbordered
        @sort = sort
        @sort_direction = sort ? (sort_direction || "desc") : sort_direction
        @render_sortable = render_sortable
        @sticky = sticky
        @columns = []
      end

      def column(label: nil, sortable: nil, sort_indicator: nil, classes: nil, header_classes: nil, lower_right: nil, &block)
        @columns << UI::TableColumn::Component.new(label:, sortable:, sort_indicator:, classes:, header_classes:, lower_right:, &block)
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

      # Stacking + background so the header paints over scrolled rows.
      def sticky_th_classes
        @sticky ? "tw:relative tw:z-10 tw:bg-gray-50 tw:dark:bg-gray-700" : nil
      end

      def table_classes
        [
          "ui-table tw:min-w-full tw:text-left tw:border-separate! tw:border-spacing-0",
          ("ui-table-bordered" if @bordered),
          @classes
        ].compact.join(" ")
      end
    end
  end
end
