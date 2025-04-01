# frozen_string_literal: true

module LoadingSpinner
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(LoadingSpinner::Component.new(text: "Loading results..."))
    end
  end
end
