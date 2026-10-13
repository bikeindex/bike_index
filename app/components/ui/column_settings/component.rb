# frozen_string_literal: true

module UI
  module ColumnSettings
    # The checkboxes that pick a table's visible columns, collapsed until a UI::Collapse opens it.
    # Render it and the table inside an element given data_attributes
    class Component < ApplicationComponent
      # narrow_hidden_columns: defaults that start hidden below Tailwind's sm breakpoint
      def self.data_attributes(storage_key:, narrow_hidden_columns: [])
        {controller: "ui--collapse ui--column-settings",
         "ui--collapse-storage-key-value": "#{storage_key}Open",
         "ui--column-settings-storage-key-value": storage_key,
         "ui--column-settings-narrow-hidden-columns-value": narrow_hidden_columns}
      end

      # columns: {cell_name => label}, each cell_name a class every cell in that column carries.
      # defaults: the cell_names shown until the viewer picks
      def initialize(columns:, defaults:)
        @columns = columns
        @defaults = defaults.map(&:to_s)
      end

      private

      def column_rows = (@columns.size / 3.0).ceil
    end
  end
end
