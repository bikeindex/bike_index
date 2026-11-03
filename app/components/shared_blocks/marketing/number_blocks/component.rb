# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module NumberBlocks
      # The marketing pages' figures, two to a row and ruled between rows. items: [value, label] pairs.
      # layout: :grid stays two to a row, :row_from_md goes four across, :stack_from_lg one per row
      class Component < ApplicationComponent
        # Each layout's [list classes, item classes] - the rule sits above every item outside the first row
        LAYOUTS = {
          grid: ["", ""],
          row_from_md: ["tw:md:grid-cols-4", "tw:md:nth-[n+3]:border-t-0 tw:md:nth-[n+3]:pt-0"],
          stack_from_lg: ["tw:lg:grid-cols-1", "tw:lg:nth-2:border-t-2 tw:lg:nth-2:pt-3"]
        }.freeze

        def initialize(items:, layout: :grid, html_class: nil)
          @items = items
          @list_classes, @item_classes = LAYOUTS.fetch(layout)
          @html_class = html_class
        end
      end
    end
  end
end
