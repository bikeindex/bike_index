# frozen_string_literal: true

module UI::LoadingSpinner
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(UI::LoadingSpinner::Component.new(text: "Loading results..."))
    end
  end
end
