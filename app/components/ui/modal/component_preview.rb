# frozen_string_literal: true

module UI
  module Modal
    class ComponentPreview < ApplicationComponentPreview
      def default
        {template: "ui/modal/component_preview/default"}
      end
    end
  end
end
