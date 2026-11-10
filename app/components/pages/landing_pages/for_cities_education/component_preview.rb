# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCitiesEducation
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::ForCitiesEducation::Component.new)
        end
      end
    end
  end
end
