# frozen_string_literal: true

module UI
  module TableList
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      def default
        {template: "ui/table_list/component_preview/default"}
      end

      def wide_definition
        {template: "ui/table_list/component_preview/default", locals: {wide_definition: true}}
      end

      # @!endgroup
    end
  end
end
