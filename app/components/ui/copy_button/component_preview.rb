# frozen_string_literal: true

module UI
  module CopyButton
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(UI::CopyButton::Component.new(value: "r/21J-HW", label: "Copy ID"))
      end
    end
  end
end
