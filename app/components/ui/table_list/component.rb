# frozen_string_literal: true

module UI
  module TableList
    # The legacy .table-list's label-beside-value rows, striped and bordered by UI::Table's CSS
    class Component < ApplicationComponent
      # .ui-table-list is .only-dev-visible's hook. UI::Table's thead draws its top edge, so the first row does here
      TABLE_CLASSES = "ui-table ui-table-bordered ui-table-list tw:mb-4 tw:w-full tw:border-separate tw:border-spacing-0 " \
        "tw:leading-normal tw:wrap-anywhere tw:[&_tr:first-child>*]:border-t " \
        "tw:[&_tr:first-child>:first-child]:rounded-tl-sm tw:[&_tr:first-child>:last-child]:rounded-tr-sm"

      CELL_CLASSES = "#{UI::TableColumn::Component.new.td_classes(bordered: true)} tw:align-top"

      # The top padding sets the smaller label on the value's first line
      LABEL_CLASSES = "#{CELL_CLASSES} tw:pt-[9px] tw:text-right tw:text-[75%] tw:leading-[1.25] tw:font-normal tw:italic"

      # value: or a block. dev_only marks the label only-dev-visible. row_attributes: the <tr>'s
      renders_many :rows, ->(label:, value: nil, dev_only: false, **row_attributes, &block) {
        tag.tr(**row_attributes) do
          tag.th(label, scope: "row", class: token_list(LABEL_CLASSES, "only-dev-visible": dev_only)) +
            tag.td(block ? capture(&block) : value, class: value_classes)
        end
      }

      # wide_definition: a wider label column, for longer labels
      def initialize(wide_definition: false, classes: nil)
        @wide_definition = wide_definition
        @classes = classes
      end

      def render? = rows?

      def call
        tag.table(class: token_list(TABLE_CLASSES, @classes)) { tag.tbody { safe_join(rows) } }
      end

      private

      def value_classes = "#{CELL_CLASSES} #{@wide_definition ? "tw:w-[70%]" : "tw:w-[85%]"}"
    end
  end
end
