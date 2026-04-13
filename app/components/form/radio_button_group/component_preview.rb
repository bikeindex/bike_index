# frozen_string_literal: true

module Form
  module RadioButtonGroup
    class ComponentPreview < ApplicationComponentPreview
      # @!group Default
      def default
        {template: "form/radio_button_group/component_preview/default"}
      end
      # @!endgroup

      # @!group With Selection
      def with_selection
        {template: "form/radio_button_group/component_preview/with_selection"}
      end
      # @!endgroup
    end
  end
end
