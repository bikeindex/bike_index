# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      include SortableHelper

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

      def column(label: nil, sortable: nil, classes: nil, header_classes: nil, lower_right: nil, &block)
        @columns << UI::TableColumn::Component.new(label:, sortable:, classes:, header_classes:, lower_right:, &block)
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

      def last_row?(row_index) = row_index == @records.length - 1

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
