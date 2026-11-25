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
      #
      # html_options go on the input, as with UI::Forms::Input - a class there joins the
      # component's own. The checkbox sits on the label's first line when it wraps.
      # A block renders in place of label, for one with markup.
      class Component < ApplicationComponent
        # Centered on the label's first line: half the line height it doesn't fill
        INPUT_CLASSES = "tw:h-4 tw:w-4 tw:shrink-0 tw:mt-[calc((1lh_-_1rem)/2)] tw:cursor-pointer " \
          "tw:disabled:cursor-not-allowed"

        def initialize(label: nil, form_builder: nil, attribute: nil, name: nil, checked: nil, value: "1",
          class_name: nil, required: false, data: {}, html_options: {})
          scoped = form_builder && attribute
          raise ArgumentError, "pass form_builder + attribute, or name" unless scoped || name

          @label = label
          @form_builder = form_builder
          @attribute = attribute
          @name = name
          @checked = checked
          @value = value
          @class_name = class_name
          @required = required
          @data = data
          @html_options = html_options.merge(class: [INPUT_CLASSES, html_options[:class]].compact.join(" "))
        end

        def call
          tag.label(class: ["twlabel tw:flex tw:cursor-pointer tw:items-start tw:gap-2 tw:has-disabled:cursor-not-allowed", @class_name].compact.join(" "), data: @data) do
            checkbox_input + tag.span(content || @label)
          end
        end

        private

        def checkbox_input
          base = @html_options.merge(required: @required)
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
