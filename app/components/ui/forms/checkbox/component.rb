# frozen_string_literal: true

module UI
  module Forms
    module Checkbox
      # A checkbox with an inline label, styled to match twlabel form fields.
      #
      # Pass `form_builder` + `attribute` for a model-scoped checkbox (like the rest
      # of UI::Forms), or a bare `name` to render a check_box_tag for params outside
      # the form's scope and for JS-only toggles. With a form builder, `checked`
      # defaults to the model's value unless overridden.
      class Component < ApplicationComponent
        def initialize(label:, form_builder: nil, attribute: nil, name: nil, checked: nil, value: "1",
          class_name: nil, data: {}, input_data: {})
          scoped = form_builder && attribute
          raise ArgumentError, "pass form_builder + attribute, or name" unless scoped || name

          @label = label
          @form_builder = form_builder
          @attribute = attribute
          @name = name
          @checked = checked
          @value = value
          @class_name = class_name
          @data = data
          @input_data = input_data
        end

        def call
          tag.label(class: ["twlabel tw:flex tw:cursor-pointer tw:items-center tw:gap-2", @class_name].compact.join(" "), data: @data) do
            checkbox_input + tag.span(@label)
          end
        end

        private

        def checkbox_input
          base = {class: "tw:h-4 tw:w-4 tw:cursor-pointer", data: @input_data}
          if @form_builder
            @form_builder.check_box(@attribute, base.merge(@checked.nil? ? {} : {checked: @checked}), @value, "0")
          else
            check_box_tag(@name, @value, @checked, base)
          end
        end
      end
    end
  end
end
