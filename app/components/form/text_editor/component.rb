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

      # Lexxy names each editor's text box from its associated <label> — without one the
      # contenteditable has no accessible name. The group label covers the whole array, so give
      # every editor a unique id and its own sr-only label (singular: "Feature slug").
      def editor_id(suffix)
        "#{@form_builder.object_name}_#{@attribute}_#{suffix}"
      end

      def item_label
        @attribute.to_s.singularize.humanize
      end

      def editor_field(value, id)
        content_tag(:div, class: "tw:flex tw:flex-col", data: {nested_form_item: ""}) do
          safe_join([
            content_tag(:label, item_label, for: id, class: "tw:sr-only"),
            helpers.lexxy_rich_textarea_tag(field_name, value, id:, "multi-line": "false", attachments: "false", class: "lexxy-content tw:w-full"),
            content_tag(:div, class: "tw:text-right") do
              content_tag(:button, "Remove", type: "button", class: "twlink tw:text-red-600", data: {action: "nested-form#remove"})
            end
          ])
        end
      end
    end
  end
end
