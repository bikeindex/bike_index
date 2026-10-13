# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      # Template Dependency: UI::TableColumn::Component

      # For a table that fills a card, passed as classes: with unbordered. Descendant selectors,
      # so they outrank the cell classes every column gets
      CARD_CLASSES = [
        "tw:[&_th]:whitespace-nowrap tw:[&_th]:border-b tw:[&_th]:border-gray-100 tw:[&_th]:bg-gray-50",
        "tw:[&_th]:px-4 tw:[&_th]:py-2.5 tw:[&_th]:text-2xs tw:[&_th]:font-normal tw:[&_th]:text-gray-400 tw:[&_th]:uppercase",
        # twlink's blue gives way to the header's gray, underlined like twlink-underlined
        "tw:[&_th_a]:text-inherit tw:[&_th_a]:underline tw:[&_th_a:hover]:decoration-2 tw:[&_th_a[data-active]]:decoration-2",
        "tw:[&_td]:bg-white tw:[&_td]:px-4 tw:[&_td]:py-2.5 tw:[&_td]:text-sm tw:[&_tr:hover_td]:bg-amber-50",
        # Whatever follows the table draws the line under it
        "tw:[&_tbody_tr:last-child_td]:border-b-0",
        "tw:dark:[&_th]:border-gray-700 tw:dark:[&_th]:bg-gray-800 tw:dark:[&_td]:bg-gray-900",
        "tw:dark:[&_tr:hover_td]:bg-gray-800"
      ].join(" ").freeze

      # Cell blocks are instance_exec'd, so this is how they reach the sort state
      attr_reader :sort_state

      # Pass cache_key (normally self.class.cache_digest) to enable per-row fragment caching.
      # cache_records: mirror the controller's `includes`, or the row serves those records stale
      def initialize(records:, sort_state: ComponentStructs::SortState.new, cache_key: nil, cache_records: nil, classes: nil, unbordered: false, render_sortable: false, sticky: false)
        @records = records
        @sort_state = sort_state
        @cache_key = cache_key
        @cache_records = cache_records
        @classes = classes
        @bordered = !unbordered
        @render_sortable = render_sortable
        @sticky = sticky
        @columns = []
      end

      # A cell block is instance_exec'd here, so it can't reach the calling component's
      # methods - a caller that needs one binds it to a local first
      # header_tooltip renders beside the header rather than in it, which a sort link would swallow
      def column(label: nil, sortable: nil, sort_indicator: nil, classes: nil, header_classes: nil, header_tooltip: nil, lower_right: nil, footer: nil, row_header: false, &block)
        @columns << UI::TableColumn::Component.new(label:, sortable:, sort_indicator:, classes:, header_classes:, header_tooltip:, lower_right:, footer:, row_header:, &block)
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
