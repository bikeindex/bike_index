# frozen_string_literal: true

module Form
  module TextEditor
    class ComponentPreview < ApplicationComponentPreview
      # @!group Examples

      # Two pre-filled single-line Lexxy editors bound to an array attribute, with add/remove
      def default
        {template: "form/text_editor/component_preview/default"}
      end

      # @!endgroup
    end
  end
end
