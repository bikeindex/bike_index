# frozen_string_literal: true

module Pages
  module Memberships
    module New
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Memberships::New::Component.new(currency: Currency.default, bikes_count: 1_234_567,
            recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000,
            recovery_displays: RecoveryDisplay.with_photo))
        end
      end
    end
  end
end
