# frozen_string_literal: true

module Form
  module RadioButtonGroup
    class ComponentPreview < ApplicationComponentPreview
      def default
        {template: "form/radio_button_group/component_preview/default"}
      end

      def with_selection
        {template: "form/radio_button_group/component_preview/with_selection"}
      end
    end
  end
end
