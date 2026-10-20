# frozen_string_literal: true

module Pages
  module Donate
    module Page
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Donate::Page::Component.new(stripe_prices:,
            recovery_displays: RecoveryDisplay.joins(:photo_processed_attachment).limit(4)))
        end

        # From a major gift link, or a newsletter's "donate $500"
        def initial_amount
          render(Pages::Donate::Page::Component.new(stripe_prices:, recovery_displays: [], initial_amount: "500"))
        end

        private

        def stripe_prices
          {basic: 500, plus: 1500, patron: 5000}.map do |membership_level, amount_cents|
            StripePrice.new(membership_level:, interval: "monthly", amount_cents:)
          end
        end
      end
    end
  end
end
