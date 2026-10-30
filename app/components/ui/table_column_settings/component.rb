# frozen_string_literal: true

module UI
  module TableColumnSettings
    # The checkboxes that pick a table's visible columns, collapsed until a UI::Collapse opens it.
    # Render it and the table inside an element given data_attributes
    class Component < ApplicationComponent
      # orderable: the hideable columns' headers drag to reorder them
      def self.data_attributes(storage_key:, controllers: nil, orderable: false)
        order = {"ui--table-column-order-storage-key-value": order_storage_key(storage_key)} if orderable
        {controller: [controllers, "ui--collapse ui--table-column-settings", ("ui--table-column-order" if orderable)].compact.join(" "),
         "ui--collapse-storage-key-value": "#{storage_key}Open",
         "ui--table-column-settings-storage-key-value": storage_key, **order}
      end

      def self.order_storage_key(storage_key) = "#{storage_key}Order"

      # columns: {cell_name => label}, each cell_name a class every cell in that column carries.
      # defaults: the cell_names shown until the viewer picks. narrow_hidden: defaults that start
      # hidden below Tailwind's sm breakpoint. always_visible: checked, and can't be unchecked.
      # hints: {cell_name => text} after its label. sections: {heading => cell_names} listed under
      # their own heading, after the rest. orderable: as data_attributes was given, which adds the
      # button returning its columns to their default order. copy_order_from: {storage_key:, label:}
      # a button taking the order of another orderable table, by its storage key, for the columns
      # both share.
      # field_name makes it a form's fields instead, open and on its own: the columns' keys are
      # their values, checked: the ones checked, and the table is left alone
      def initialize(columns:, defaults:, narrow_hidden: [], always_visible: [], hints: {}, sections: {}, orderable: false,
        copy_order_from: nil, field_name: nil, checked: [])
        @columns = columns
        @defaults = defaults
        @narrow_hidden = narrow_hidden
        @always_visible = always_visible
        @hints = hints
        @sections = sections
        @orderable = orderable
        @copy_order_from = copy_order_from
        @field_name = field_name
        @checked = checked
      end

      private

      def column_groups
        sectioned = @sections.values.flatten
        [[nil, @columns.except(*sectioned)], *@sections.map { |heading, keys| [heading, @columns.slice(*keys)] }]
          .reject { |_heading, columns| columns.empty? }
      end

      def column_rows(columns) = (columns.size / 3.0).ceil

      def panel_data = @field_name ? {controller: "ui--table-column-settings"} : {"ui--collapse-target": "content"}

      def checkbox_label(key, label)
        return label unless @hints[key]

        safe_join([label, " ", tag.small(@hints[key], class: "tw:text-gray-400 tw:dark:text-gray-500")])
      end

      def checkbox_html_options(key)
        disabled = @always_visible.include?(key)
        toggle = {"ui--table-column-settings-target": "checkbox", action: "ui--table-column-settings#update"} unless disabled
        {id: "#{@field_name || "table_column_settings"}_#{key}".parameterize(separator: "_"), class: "tw:accent-blue-600", disabled:,
         data: {**toggle, default: @defaults.include?(key), narrow_hidden: @narrow_hidden.include?(key)}}
      end
    end
  end
end
