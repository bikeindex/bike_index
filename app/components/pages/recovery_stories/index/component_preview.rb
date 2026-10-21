# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Index
      class ComponentPreview < ApplicationComponentPreview
        def default
          recovery_displays = RecoveryDisplay.with_attached_photo_processed.limit(9)
          render(Pages::RecoveryStories::Index::Component.new(recovery_displays:,
            pagy: Pagy::Offset.new(count: RecoveryDisplay.count, page: 1, limit: 9),
            total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345,
            organizations_count: 1_000, currency: Currency.default))
        end
      end
    end
  end
end
