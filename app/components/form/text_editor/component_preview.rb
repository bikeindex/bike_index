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

      # Restricted toolbar -- only the buttons listed in toolbar_buttons: are shown
      def custom_toolbar
        {template: "form/text_editor/component_preview/default",
         locals: {size: :default, toolbar_buttons: %i[bold italic link undo redo]}}
      end

      # @!endgroup
    end
  end
end
