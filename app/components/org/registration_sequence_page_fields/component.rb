# frozen_string_literal: true

module Org
  module RegistrationSequencePageFields
    class Component < ApplicationComponent
      def initialize(form_builder:)
        @form_builder = form_builder
      end

      private

      # A single bullet: a single-line (multi-line=false) Lexxy editor submitting into the
      # bullet_points array, plus a remove button handled by the nested-form controller.
      def bullet_field(value)
        content_tag(:div, class: "tw:flex tw:flex-col", data: {nested_form_item: ""}) do
          safe_join([
            helpers.lexxy_rich_textarea_tag("#{@form_builder.object_name}[bullet_points][]", value,
              "multi-line": "false", attachments: "false", class: "lexxy-content tw:w-full"),
            content_tag(:div, class: "tw:text-right") do
              content_tag(:button, "Remove", type: "button", class: "twlink tw:text-red-600", data: {action: "nested-form#remove"})
            end
          ])
        end
      end
    end
  end
end
