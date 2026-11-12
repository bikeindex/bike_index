# frozen_string_literal: true

module UI
  module Table
    module List
      # The legacy .table-list's label-beside-value rows, striped and bordered by UI::Table::Base's CSS
      class Component < ApplicationComponent
        # .ui-table-list is .only-dev-visible's hook
        TABLE_CLASSES = "ui-table ui-table-bordered ui-table-list tw:mb-4 tw:w-full tw:border-separate tw:border-spacing-0 " \
          "tw:leading-normal"

        CELL_CLASSES = "#{UI::TableColumn::Component::BORDERED_TD_CLASSES} tw:align-top"

        # The top padding sets the smaller label on the value's first line
        LABEL_CLASSES = "#{CELL_CLASSES} tw:pt-[9px] tw:text-right tw:text-[75%] tw:leading-[1.25] tw:font-normal tw:italic"

        WIDE_LABEL_CLASSES = "#{CELL_CLASSES} tw:text-left tw:font-normal"

        # value: or a block. A falsy if: skips the row, but value: is evaluated anyway,
        # so a value that needs the condition goes in the block
        renders_many :rows, ->(label:, value: nil, dev_only: false, **row_attributes, &block) {
          next "" unless row_attributes.fetch(:if, true)

          tag.tr(**row_attributes.except(:if)) do
            tag.th(label, scope: "row", class: token_list(@wide_definition ? WIDE_LABEL_CLASSES : LABEL_CLASSES, "only-dev-visible": dev_only)) +
              tag.td(block ? capture(&block) : value, class: value_classes)
          end
        }

        # wide_definition: full-size labels take the width, beside short values (counts, amounts) that don't wrap
        def initialize(wide_definition: false, classes: nil)
          @wide_definition = wide_definition
          @classes = classes
        end

        def render? = rows.any? { it.to_s.present? }

        def call
          tag.table(class: token_list(TABLE_CLASSES, @classes)) { tag.tbody { safe_join(rows) } }
        end

        private

        def value_classes
          return "#{CELL_CLASSES} tw:w-px tw:whitespace-nowrap tw:text-right" if @wide_definition

          # UI::Code's own wrap-break-word leaves a long value its full width, overflowing a narrow list
          "#{CELL_CLASSES} tw:wrap-anywhere tw:[&_code]:wrap-anywhere tw:w-[85%]"
        end
      end
    end
  end
end
