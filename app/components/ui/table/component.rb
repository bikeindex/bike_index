# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      # Pass cache_key to enable per-row fragment caching (e.g. cache_key: "admin-users").
      def initialize(records:, sort_state: ComponentStates::SortState.new, cache_key: nil, classes: nil, unbordered: false, render_sortable: false, sticky: false)
        @records = records
        @sort_state = sort_state
        @cache_key = cache_key
        @classes = classes
        @bordered = !unbordered
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

      # Cell blocks are instance_exec'd, so this is how they reach the search params
      def sortable_search_params = @sort_state.search_params

      private

      def sortable_url(sort, direction)
        url_for(@sort_state.url_params(sort:, direction:))
      end

      def current_sort
        @current_sort ||= sortable_columns.include?(@sort_state.sort) ? @sort_state.sort : default_sort_column
      end

      def current_direction
        @sort_state.direction || "desc"
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
