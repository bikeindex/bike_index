# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCommunityGroups
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::LandingPages::ForCommunityGroups::Component.new(recovery_displays: RecoveryDisplay.with_photo,
            total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000))
        end
      end
    end
  end
end
