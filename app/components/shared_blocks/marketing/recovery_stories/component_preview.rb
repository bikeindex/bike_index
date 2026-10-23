# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module RecoveryStories
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(SharedBlocks::Marketing::RecoveryStories::Component.new(heading: "Bikes that came home",
            recovery_displays: RecoveryDisplay.with_photo.limit(4)))
        end

        def without_stories
          render(SharedBlocks::Marketing::RecoveryStories::Component.new(heading: "Bikes that came home",
            recovery_displays: []))
        end
      end
    end
  end
end
