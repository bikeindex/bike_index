# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCities
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::ForCities::Component.new)
        end
      end
    end
  end
end
