# frozen_string_literal: true

module UI
  module CardTable
    # A UI::Table that fills a card edge to edge, its first column frozen against the
    # horizontal scroll. Columns are declared as on UI::Table, and their blocks run there
    class Component < ApplicationComponent
      # Descendant selectors, so they outrank the cell classes UI::Table gives every column
      TABLE_CLASSES = [
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

      # Shadowed once the ui--table-overflow controller flags there's any to scroll
      FROZEN_COLUMN_CLASSES = "tw:w-px tw:sticky tw:left-0 tw:z-1 tw:border-r tw:border-r-gray-100 " \
        "tw:group-data-overflowing/card-table:shadow-[2px_0_6px_rgba(26,26,31,0.04)] tw:dark:border-r-gray-700"

      # [&>div] is UI::Table's scroller, whose bottom spacing would part the table from what
      # follows it. The after: box mirrors the frozen column's divider and shadow on the right
      # edge while there's more to scroll, except in a full-bleed row that runs off the page
      WRAPPER_CLASSES = "tw:group/card-table tw:relative tw:[&>div]:mb-0 tw:[&>div]:pb-0 tw:data-overflowing:after:absolute " \
        "tw:data-overflowing:after:inset-y-0 tw:data-overflowing:after:left-[calc(100%-1px)] tw:data-overflowing:after:z-2 " \
        "tw:data-overflowing:after:w-4 tw:data-overflowing:after:border-l tw:data-overflowing:after:border-gray-100 " \
        "tw:data-overflowing:after:shadow-[-2px_0_6px_rgba(26,26,31,0.04)] tw:dark:data-overflowing:after:border-gray-700 " \
        "tw:data-scrolled-end:after:hidden tw:@max-[672px]/twwiderow:after:hidden"

      # data: the wrapper's, whose controllers join ui--table-overflow. The rest go to UI::Table
      def initialize(data: {}, **table_options)
        @data = data
        @table_options = table_options
        @columns = []
      end

      def column(**options, &block)
        @columns << [options, block]
        nil
      end

      def before_render
        content
      end

      private

      def wrapper_data
        @data.merge(controller: ["ui--table-overflow", @data[:controller]].compact.join(" "))
      end

      def column_options(options, index)
        options.merge(classes: [(FROZEN_COLUMN_CLASSES if index.zero?), options[:classes]].compact.join(" "))
      end
    end
  end
end
