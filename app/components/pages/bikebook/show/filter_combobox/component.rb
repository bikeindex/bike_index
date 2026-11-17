# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      module FilterCombobox
        # A filter's combobox, its options added in the browser from the catalog. The note
        # follows the label. A single choice offers Any unless it's `any: false`
        class Component < ApplicationComponent
          SELECTION_ACTIONS = "hw-combobox:selection->bikebook--catalog-filters#applySelection " \
            "hw-combobox:removal->bikebook--catalog-filters#applySelection"

          cache_on :name, :label, :placeholder, :note, :multiselect, :any, :rich_display

          def initialize(name:, label:, placeholder:, note: nil, multiselect: false, any: true, rich_display: nil)
            @name = name
            @any = any
            @rich_display = rich_display
            @label = label
            @placeholder = placeholder
            @note = note
            @multiselect = multiselect
          end

          def call
            render(UI::Forms::Group::Component.new(attribute: @name, label_text: @label, optional_badge: false,
              wrapper_class: nil)) do |group|
              group.with_label_note { @note } if @note
              render(UI::Forms::Combobox::Component.new(name: @name, dialog_label: @label, rich_display: @rich_display,
                multiselect_chip_src: (bikebook_path if @multiselect), include_blank: (translation(".any") if @any && !@multiselect),
                html_options: {value: "", placeholder: @placeholder,
                               data: {"bikebook--catalog-filters-target": "field", filter_label: @label, action: SELECTION_ACTIONS}}))
            end
          end

          private

          attr_reader :name, :label, :placeholder, :note, :multiselect, :any, :rich_display
        end
      end
    end
  end
end
