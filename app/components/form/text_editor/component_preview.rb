# frozen_string_literal: true

module Form
  module TextEditor
    class ComponentPreview < ApplicationComponentPreview
      # @!group Sizes

      # Normal size (the default)
      def default
        {template: "form/text_editor/component_preview/default", locals: {size: :normal}}
      end

      # Compact size (size: :small)
      def small
        {template: "form/text_editor/component_preview/default", locals: {size: :small}}
      end

      # @!endgroup
    end
  end
end
