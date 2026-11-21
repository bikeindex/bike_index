# frozen_string_literal: true

module Pages
  module LandingPages
    module ForBikeShops
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::ForBikeShops::Component.new(recovery_displays: RecoveryDisplay.all))
        end
      end
    end
  end
end
