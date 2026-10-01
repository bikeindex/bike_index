# frozen_string_literal: true

module Backfills
  # Events stored before stripe_event_id have only the object id, in stripe_id, and were
  # processed as they arrived. Stripe keeps events for 30 days, so their ids can't be recovered
  class StripeEventPayloadJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      stripe_events = StripeEvent.where(stripe_event_id: nil)
      stripe_events.where(payload: nil).update_all(
        "payload = jsonb_build_object('data', jsonb_build_object('object', jsonb_build_object('id', stripe_id)))"
      )
      stripe_events.where(name: StripeEvent::KNOWN_EVENTS).update_all("processed_at = created_at")
    end
  end
end
