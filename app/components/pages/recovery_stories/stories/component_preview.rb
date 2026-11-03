# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Stories
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::RecoveryStories::Stories::Component.new(recovery_displays: RecoveryDisplay.with_attached_photo_processed.limit(9),
            pagy: Pagy::Offset.new(count: RecoveryDisplay.count, page: 1, limit: 9)))
        end
      end
    end
  end
end
