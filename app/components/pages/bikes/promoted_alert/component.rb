# frozen_string_literal: true

module Pages
  module Bikes
    module PromotedAlert
      # Buying a Promoted Theft Alert: the plans, a preview of the ad, and the photo it uses.
      # Posts to Bikes::TheftAlertsController#create, which hands off to Stripe checkout
      class Component < ApplicationComponent
        # plans: the active plans in the viewer's language, cheapest first
        # theft_alerts: the ones already bought for this theft, listed below
        def initialize(bike:, stolen_record:, plans:, selected_plan:, currency:, theft_alerts: [])
          @bike = bike
          @stolen_record = stolen_record
          @plans = plans
          @selected_plan = selected_plan || plans.first
          @currency = currency
          @theft_alerts = theft_alerts
        end

        private

        def cycle_type = @bike.type

        def best_value_plan = @best_value_plan ||= @plans.max_by(&:amount_cents)

        def images = @images ||= @bike.public_images.to_a

        # The alert falls back to the stock photo when the bike has none of its own
        def stock_only? = images.none? && @bike.stock_photo_url.present?

        def preview_url = images.first&.image_url(:medium) || @bike.stock_photo_url

        def location = [@stolen_record.city, @stolen_record.region].compact_blank.join(", ")

        def purchase_text(plan) = translation(".purchase_plan", plan: plan.name, price: amount_display(plan))
      end
    end
  end
end
