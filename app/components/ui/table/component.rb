# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      # Cell blocks are instance_exec'd, so this is how they reach the search params
      attr_reader :sortable_search_params

      # Pass cache_key to enable per-row fragment caching (e.g. cache_key: "admin-users").
      def initialize(records:, cache_key: nil, classes: nil, unbordered: false, sort: nil, sort_direction: nil, sortable_search_params: {}, render_sortable: false, sticky: false)
        @records = records
        @sortable_search_params = sortable_search_params
        @cache_key = cache_key
        @classes = classes
        @bordered = !unbordered
        @sort = sort
        @sort_direction = sort_direction
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

      def sortable_url(sort, direction)
        url_for(@sortable_search_params.merge(sort:, direction:))
      end

      def current_sort
        @current_sort ||= sortable_columns.include?(@sort) ? @sort : default_sort_column
      end

      def current_direction
        @sort_direction || "desc"
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
          "ui-table tw:min-w-full tw:text-left tw:leading-[1.25] tw:border-separate tw:border-spacing-0",
          ("ui-table-bordered" if @bordered),
          @classes
        ].compact.join(" ")
      end
    end
  end
end
