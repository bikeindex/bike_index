# frozen_string_literal: true

module Form
  module TextEditor
    class ComponentPreview < ApplicationComponentPreview
      # @!group Sizes

      # Full multi-line editor (the default)
      def default
        {template: "form/text_editor/component_preview/default", locals: {size: :default}}
      end

      # Compact single-line editor (size: :single_line)
      def single_line
        {template: "form/text_editor/component_preview/default", locals: {size: :single_line}}
      end

      # @!endgroup
    end
  end
end
