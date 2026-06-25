# frozen_string_literal: true

module Org
  module RegistrationSequencePageFields
    class Component < ApplicationComponent
      def initialize(form_builder:)
        @form_builder = form_builder
      end

      private

      def bullet_field(value)
        content_tag(:div, class: "tw:flex tw:items-start tw:gap-2", data: {nested_form_item: ""}) do
          safe_join([
            text_area_tag("#{@form_builder.object_name}[bullet_points][]", value, rows: 2, class: "twinput tw:w-full tw:font-mono"),
            content_tag(:button, "Remove", type: "button", class: "twlink tw:mt-2 tw:text-red-600", data: {action: "nested-form#remove"})
          ])
        end
      end
    end
  end
end
