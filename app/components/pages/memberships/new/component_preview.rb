# frozen_string_literal: true

module Pages
  module Memberships
    module New
      class ComponentPreview < ApplicationComponentPreview
        def default
          stripe_prices = {basic: 500, plus: 1500, patron: 5000}.flat_map do |membership_level, amount_cents|
            [StripePrice.new(membership_level:, interval: "monthly", amount_cents:),
              StripePrice.new(membership_level:, interval: "yearly", amount_cents: amount_cents * 10)]
          end
          render(Pages::Memberships::New::Component.new(stripe_prices:, bikes_count: 1_234_567,
            recoveries_count: 18_263, recoveries_value: 38_412_345, organizations_count: 1_000,
            recovery_displays: RecoveryDisplay.with_photo))
        end
      end
    end
  end
end
