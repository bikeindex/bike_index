# frozen_string_literal: true

module UI::Button
  class ComponentPreview < ApplicationComponentPreview
    # This is a fake component preview, it's just elements styled with class names
    # ... but it's useful to have the buttons displayed somewhere
    def default
      {template: "ui/button/component_preview/default"}
    end
  end
end
