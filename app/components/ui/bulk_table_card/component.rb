# frozen_string_literal: true

module UI
  module BulkTableCard
    # A full-bleed card around a UI::CardTable, rendered as its content, with its column settings
    # and, given a form, bulk actions on the rows it checks. The table's first column is the rows'
    # checkboxes, each a table-multi-checkbox target, under toggle_all_button. Editing a row's
    # field checks it, and a submit button with data-discards-edits confirms before dropping edits
    class Component < ApplicationComponent
      renders_one :description
      renders_one :actions

      # form: form_with's options, or nil to leave out the form. data: the form's (or the div's),
      # its controller and action joining these
      def initialize(storage_key:, columns:, defaults:, narrow_hidden: [], form: nil, data: {})
        @storage_key = storage_key
        @columns = columns
        @defaults = defaults
        @narrow_hidden = narrow_hidden
        @form = form
        @data = data
      end

      def toggle_all_button
        render(UI::Button::Component.new(text: check_mark, color: :link, title: "Toggle all checked",
          aria: {label: "Toggle all checked"}, data: {action: "click->table-multi-checkbox#toggleAll"}))
      end

      private

      def wrapper(&)
        classes = "tw:col-span-full tw:min-w-0 tw:rounded-xl tw:twfullbleed #{UI::Card::Component::BASE_CLASSES}"
        return form_with(**@form, class: classes, data: wrapper_data, &) if @form

        tag.div(class: classes, data: wrapper_data, &)
      end

      def wrapper_data
        data = UI::TableColumnSettings::Component.data_attributes(storage_key: @storage_key, orderable: true,
          controllers: token_list(("table-multi-checkbox" if @form), @data[:controller]).presence)
        selection = "input->table-multi-checkbox#selectRow submit->table-multi-checkbox#confirmDiscard" if @form
        @data.merge(data, action: token_list(data[:action], selection, @data[:action]))
      end
    end
  end
end
