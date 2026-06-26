# frozen_string_literal: true

module Form
  module TextEditor
    # Editable list of single-line Lexxy editors bound to an array attribute (e.g. bullet_points).
    # Each editor submits into "<object_name>[<attribute>][]"; add/remove is handled by the
    # nested-form Stimulus controller. Lexxy must be loaded on the page (data-controller="lexxy").
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, label: nil, add_label: nil)
        @form_builder = form_builder
        @attribute = attribute
        @label = label.nil? ? attribute.to_s.humanize : label
        @add_label = add_label || "Add #{attribute.to_s.singularize.humanize.downcase}"
      end

      private

      def field_name
        "#{@form_builder.object_name}[#{@attribute}][]"
      end

      def values
        Array(@form_builder.object.public_send(@attribute))
      end

      def editor_field(value)
        content_tag(:div, class: "tw:flex tw:flex-col", data: {nested_form_item: ""}) do
          safe_join([
            helpers.lexxy_rich_textarea_tag(field_name, value, "multi-line": "false", attachments: "false", class: "lexxy-content tw:w-full"),
            content_tag(:div, class: "tw:text-right") do
              content_tag(:button, "Remove", type: "button", class: "twlink tw:text-red-600", data: {action: "nested-form#remove"})
            end
          ])
        end
      end
    end
  end
end
