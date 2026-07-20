# frozen_string_literal: true

module UI
  module Forms
    module Checkbox
      # A checkbox with an inline label, styled to match twlabel form fields.
      # Uses check_box_tag (top-level param name) rather than a form builder, so
      # it works for params outside the form's scope and for JS-only toggles.
      class Component < ApplicationComponent
        def initialize(name:, label:, checked: false, value: "1", class_name: nil, data: {}, input_data: {})
          @name = name
          @label = label
          @checked = checked
          @value = value
          @class_name = class_name
          @data = data
          @input_data = input_data
        end

        def call
          tag.label(class: ["twlabel tw:flex tw:items-center tw:gap-2", @class_name].compact.join(" "), data: @data) do
            check_box_tag(@name, @value, @checked, class: "tw:h-4 tw:w-4", data: @input_data) +
              tag.span(@label)
          end
        end
      end
    end
  end
end
