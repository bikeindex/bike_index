# frozen_string_literal: true

module UI
  module CopyButton
    class ComponentPreview < ApplicationComponentPreview
      def default
        {template: "ui/copy_button/component_preview/default"}
      end

      def tooltip
        render(UI::CopyButton::Component.new(value: "m/trek/2025/fetch", label: "Copy ID", tooltip: true))
      end
    end
  end
end
