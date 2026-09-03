# frozen_string_literal: true

module Pages
  module Homepage
    module ForButtons
      class ComponentPreview < ApplicationComponentPreview
        # @display kelsey_stylesheet true
        def default
          render(Pages::Homepage::ForButtons::Component.new)
        end
      end
    end
  end
end
