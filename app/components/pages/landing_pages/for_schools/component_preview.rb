# frozen_string_literal: true

module Pages
  module LandingPages
    module ForSchools
      class ComponentPreview < ApplicationComponentPreview
        # @display kelsey_stylesheet true
        def default
          render(Pages::LandingPages::ForSchools::Component.new)
        end
      end
    end
  end
end
