# frozen_string_literal: true

module Pages
  module LandingPages
    module ForCommunityGroups
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::ForCommunityGroups::Component.new(recovery_displays: RecoveryDisplay.with_photo,
            sign_up_path: "/organizations/new?kind=bike_advocacy")))
        end
      end
    end
  end
end
