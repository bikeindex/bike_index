# frozen_string_literal: true

module Pages
  module LandingPages
    module ForLawEnforcement
      class ComponentPreview < ApplicationComponentPreview
        # @display kelsey_stylesheet true
        def default
          render(Pages::LandingPages::ForLawEnforcement::Component.new)
        end
      end
    end
  end
end
