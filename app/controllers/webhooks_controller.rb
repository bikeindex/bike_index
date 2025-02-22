# frozen_string_literal: true

class WebhooksController < ApplicationController
  STRIPE_WEBHOOK_SECRET = ENV["STRIPE_WEBHOOK_SECRET"].freeze

  def stripe
    payload = request.body.read
    # Retrieve the event by verifying the signature using the raw body and secret if webhook signing is configured.
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    event = nil

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, STRIPE_WEBHOOK_SECRET)
    rescue JSON::ParserError => e
      # Invalid payload
      render json: {success: false, message: "invalid payload"}, status: 400
      return
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      render json: {success: false, message: "invalid signature"}, status: 400
      return
    end


    stripe_event = StripeEvent.create_from(event)
    if stripe_event.known_event?
      stripe_event.stripe_subscription.update_from_stripe!

      render json: {success: true}
    else
      render json: {success: false, message: "Unhandled event #{stripe_event.name}"}, status: 400
      return
    end
  end
end
