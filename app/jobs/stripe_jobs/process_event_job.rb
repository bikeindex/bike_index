# frozen_string_literal: true

module StripeJobs
  class ProcessEventJob < ApplicationJob
    sidekiq_options queue: "high_priority"

    def perform(stripe_event_id)
      stripe_event = StripeEvent.find_by(id: stripe_event_id)
      return if stripe_event.blank? || stripe_event.processed_at.present?

      data_object = Stripe::Event.construct_from(stripe_event.payload).data.object
      if stripe_event.checkout?
        if data_object.subscription.present?
          update_stripe_subscription(Stripe::Subscription.retrieve(data_object.subscription), data_object)
        end
      elsif stripe_event.subscription?
        update_stripe_subscription(data_object)
      end
      stripe_event.update!(processed_at: Time.current)
    end

    private

    def update_stripe_subscription(stripe_subscription_obj, stripe_checkout_session = nil)
      StripeSubscription.create_or_update_from_stripe!(stripe_subscription_obj:, stripe_checkout_session:)
    end
  end
end
