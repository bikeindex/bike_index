# frozen_string_literal: true

module Pages
  module LandingPages
    module ForBikeShops
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::ForBikeShops::Component.new(**options))
        end

        def signed_up
          render(Pages::LandingPages::ForBikeShops::Component.new(**options, signed_up: true))
        end

        private

        def options
          {total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000,
           recovery_displays: RecoveryDisplay.limit(3), feedback: Feedback.new}
        end
      end
    end
  end
end
