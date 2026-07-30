# frozen_string_literal: true

module UI
  module Modal
    class ComponentPreview < ApplicationComponentPreview
      def default
        {template: "ui/modal/component_preview/default"}
      end

      def open_on_connect
        {template: "ui/modal/component_preview/open_on_connect"}
      end
    end
  end
end
