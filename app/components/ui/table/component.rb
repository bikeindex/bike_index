# frozen_string_literal: true

module UI
  module Table
    class Component < ApplicationComponent
      # Template Dependency: UI::TableColumn::Component

      # Descendant selectors, so they outrank the cell classes every column gets
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

      # A column frozen against the table's horizontal scroll, inside an element given
      # FROZEN_WRAPPER_CLASSES and the ui--table-overflow controller. Shadowed once there's any to scroll
      FROZEN_COLUMN_CLASSES = "tw:w-px tw:sticky tw:left-0 tw:z-1 tw:border-r tw:border-r-gray-100 " \
        "tw:group-data-overflowing/ui-table:shadow-[2px_0_6px_rgba(26,26,31,0.04)] tw:dark:border-r-gray-700"

      # [&>div] is the scroller, whose bottom spacing would part the table from what follows it.
      # The after: box mirrors the frozen column's divider and shadow on the right edge while
      # there's more to scroll, except in a full-bleed row that runs off the page
      FROZEN_WRAPPER_CLASSES = "tw:group/ui-table tw:relative tw:[&>div]:mb-0 tw:[&>div]:pb-0 tw:data-overflowing:after:absolute " \
        "tw:data-overflowing:after:inset-y-0 tw:data-overflowing:after:left-[calc(100%-1px)] tw:data-overflowing:after:z-2 " \
        "tw:data-overflowing:after:w-4 tw:data-overflowing:after:border-l tw:data-overflowing:after:border-gray-100 " \
        "tw:data-overflowing:after:shadow-[-2px_0_6px_rgba(26,26,31,0.04)] tw:dark:data-overflowing:after:border-gray-700 " \
        "tw:data-scrolled-end:after:hidden tw:@max-[672px]/twwiderow:after:hidden"

      # Cell blocks are instance_exec'd, so this is how they reach the sort state
      attr_reader :sort_state

      # Pass cache_key (normally self.class.cache_digest) to enable per-row fragment caching.
      # cache_records: mirror the controller's `includes`, or the row serves those records stale
      def initialize(records:, sort_state: ComponentStructs::SortState.new, cache_key: nil, cache_records: nil, classes: nil, unbordered: false, card: false, render_sortable: false, sticky: false)
        @records = records
        @sort_state = sort_state
        @cache_key = cache_key
        @cache_records = cache_records
        @classes = classes
        @bordered = !(unbordered || card)
        @card = card
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

      def wrapper_classes = @card ? "twgutter-bleed tw:overflow-x-scroll" : "twgutter-bleed tw:mb-4 tw:overflow-x-scroll tw:pb-3"

      def table_classes
        [
          "ui-table tw:min-w-full tw:text-left tw:leading-[1.25] tw:border-separate tw:border-spacing-0",
          ("ui-table-bordered" if @bordered),
          (CARD_CLASSES if @card),
          @classes
        ].compact.join(" ")
      end
    end
  end
end
