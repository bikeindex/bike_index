# frozen_string_literal: true

module UI
  module ColumnSettings
    # The checkboxes that pick a table's visible columns, collapsed until a UI::Collapse opens it.
    # Render it and the table inside an element given data_attributes
    class Component < ApplicationComponent
      ORDER_ACTIONS = "dragstart->ui--table-column-order#dragStart dragover->ui--table-column-order#dragOver " \
        "drop->ui--table-column-order#drop dragend->ui--table-column-order#dragEnd"

      # orderable: the hideable columns' headers drag to reorder them
      def self.data_attributes(storage_key:, controllers: nil, orderable: false)
        order = {"ui--table-column-order-storage-key-value": "#{storage_key}Order", action: ORDER_ACTIONS} if orderable
        {controller: [controllers, "ui--collapse ui--column-settings", ("ui--table-column-order" if orderable)].compact.join(" "),
         "ui--collapse-storage-key-value": "#{storage_key}Open",
         "ui--column-settings-storage-key-value": storage_key, **order}
      end

      # columns: {cell_name => label}, each cell_name a class every cell in that column carries.
      # defaults: the cell_names shown until the viewer picks. narrow_hidden: defaults that start
      # hidden below Tailwind's sm breakpoint
      def initialize(columns:, defaults:, narrow_hidden: [])
        @columns = columns
        @defaults = defaults
        @narrow_hidden = narrow_hidden
      end

      private

      def column_rows = (@columns.size / 3.0).ceil
    end
  end
end
