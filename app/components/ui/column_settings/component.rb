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
      # hidden below Tailwind's sm breakpoint. always_visible: checked, and can't be unchecked.
      # hints: {cell_name => text} under its label.
      # field_name makes it a form's fields instead, open and on its own: the columns' keys are
      # their values, checked: the ones checked, and the table is left alone
      def initialize(columns:, defaults:, narrow_hidden: [], always_visible: [], hints: {}, field_name: nil, checked: [])
        @columns = columns
        @defaults = defaults
        @narrow_hidden = narrow_hidden
        @always_visible = always_visible
        @hints = hints
        @field_name = field_name
        @checked = checked
      end

      private

      def column_rows = (@columns.size / 3.0).ceil

      def panel_data = @field_name ? {controller: "ui--column-settings"} : {"ui--collapse-target": "content"}

      def checkbox_label(key, label)
        return label unless @hints[key]

        safe_join([label, tag.small(@hints[key], class: "tw:block tw:text-gray-400 tw:dark:text-gray-500")])
      end

      def checkbox_html_options(key)
        disabled = @always_visible.include?(key)
        toggle = {"ui--column-settings-target": "checkbox", action: "ui--column-settings#update"} unless disabled
        {id: "#{@field_name || "column_settings"}_#{key}".parameterize(separator: "_"), class: "tw:accent-blue-600", disabled:,
         data: {**toggle, default: @defaults.include?(key), narrow_hidden: @narrow_hidden.include?(key)}}
      end
    end
  end
end
