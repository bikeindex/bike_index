# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Index
      class ComponentPreview < ApplicationComponentPreview
        def default
          recovery_displays = RecoveryDisplay.with_attached_photo_processed.limit(9)
          render(Pages::RecoveryStories::Index::Component.new(recovery_displays:,
            pagy: Pagy::Offset.new(count: RecoveryDisplay.count, page: 1, limit: 9),
            stripe_prices: StripePrice.active_for(Currency.default)))
        end
      end
    end
  end
end
