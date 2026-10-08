# frozen_string_literal: true

module Pages
  module Bikebook
    module Show
      module FilterCombobox
        # A filter's combobox, its options added in the browser from the catalog. Content
        # follows the label
        class Component < ApplicationComponent
          SELECTION_ACTIONS = "hw-combobox:selection->bikebook--catalog-filters#applySelection " \
            "hw-combobox:removal->bikebook--catalog-filters#applySelection"

          def initialize(name:, label:, placeholder:, multiselect: false, full_width: false)
            @name = name
            @label = label
            @placeholder = placeholder
            @multiselect = multiselect
            @full_width = full_width
          end

          def call
            render(UI::Forms::Group::Component.new(attribute: @name, label_text: @label, optional_badge: false,
              wrapper_class: ("tw:max-w-md" unless @full_width))) do |group|
              group.with_label_note { content } if content?
              render(UI::Forms::Combobox::Component.new(name: @name, dialog_label: @label,
                multiselect_chip_src: (bike_book_path if @multiselect), include_blank: (translation(".any") unless @multiselect),
                html_options: {value: "", placeholder: @placeholder,
                               data: {"bikebook--catalog-filters-target": "field", filter_label: @label, action: SELECTION_ACTIONS}}))
            end
          end
        end
      end
    end
  end
end
