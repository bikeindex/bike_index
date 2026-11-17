# frozen_string_literal: true

module Pages
  module Donate
    module YearEnd
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Donate::YearEnd::Component.new(stripe_prices:))
        end

        # An email whose source names the recovered audience
        def recovered
          render(Pages::Donate::YearEnd::Component.new(stripe_prices:, referral_source: "eoy-2026-recovered"))
        end

        # From a major gift link
        def initial_amount
          render(Pages::Donate::YearEnd::Component.new(stripe_prices:, initial_amount: "500"))
        end

        private

        def stripe_prices = StripePrice.active_for(Currency.default)
      end
    end
  end
end
