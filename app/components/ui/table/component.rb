# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      # Template Dependency: UI::TableColumn::Component
      # Cell blocks are instance_exec'd, so this is how they reach the sort state
      attr_reader :sort_state

      # Pass cache_key (normally self.class.cache_digest) to enable per-row fragment caching.
      # cache_records: mirror the controller's `includes`, or the row serves those records stale
      def initialize(records:, sort_state: ComponentStructs::SortState.new, cache_key: nil, cache_records: nil, classes: nil, unbordered: false, render_sortable: false, sticky: false, sort_link_class: "twlink")
        @records = records
        @sort_state = sort_state
        @cache_key = cache_key
        @cache_records = cache_records
        @classes = classes
        @bordered = !unbordered
        @render_sortable = render_sortable
        @sticky = sticky
        @sort_link_class = sort_link_class
        @columns = []
      end

      # A cell block is instance_exec'd here, so it can't reach the calling component's
      # methods - a caller that needs one binds it to a local first
      # header_tooltip renders beside the header rather than in it, which a sort link would swallow
      def column(label: nil, sortable: nil, sort_indicator: nil, classes: nil, header_classes: nil, header_tooltip: nil, lower_right: nil, footer: nil, &block)
        @columns << UI::TableColumn::Component.new(label:, sortable:, sort_indicator:, classes:, header_classes:, header_tooltip:, lower_right:, footer:, &block)
        nil
      end

      def before_render
        content
      end

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

      def cache_records_for(record) = Array(@cache_records&.call(record))

      def footer?
        @columns.any?(&:footer)
      end

      def sortable_table
        sortable_columns.any?
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
