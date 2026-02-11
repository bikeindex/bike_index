# frozen_string_literal: true

class WebhooksController < ApplicationController
  STRIPE_WEBHOOK_SECRET = ENV["STRIPE_WEBHOOK_SECRET"].freeze
  STRAVA_WEBHOOK_VERIFY_TOKEN = ENV["STRAVA_WEBHOOK_VERIFY_TOKEN"].freeze

  skip_before_action :verify_authenticity_token

  def strava
    if request.get?
      strava_verify_subscription
    else
      strava_receive_event
    end
  end

  def stripe
    payload = request.body.read
    # Retrieve the event by verifying the signature using the raw body and secret if webhook signing is configured.
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    event = nil

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, STRIPE_WEBHOOK_SECRET)
    rescue JSON::ParserError
      # Invalid payload
      render json: {success: false, message: "invalid payload"}, status: 400
      return
    rescue Stripe::SignatureVerificationError
      # Invalid signature
      render json: {success: false, message: "invalid signature"}, status: 400
      return
    end

    stripe_event = StripeEvent.create_from(event)
    if stripe_event.known_event?
      stripe_event.update_bike_index_record!

      render json: {success: true}
    else
      render json: {success: false, message: "Unhandled event #{stripe_event.name}"}, status: 400
      nil
    end
  end

  private

  def strava_verify_subscription
    if params["hub.verify_token"] == STRAVA_WEBHOOK_VERIFY_TOKEN
      render json: {"hub.challenge" => params["hub.challenge"]}, status: :ok
    else
      head :forbidden
    end
  end

  def strava_receive_event
    strava_integration = StravaIntegration.find_by(athlete_id: params["owner_id"].to_s)
    if strava_integration
      StravaRequest.create!(
        strava_integration_id: strava_integration.id,
        user_id: strava_integration.user_id,
        request_type: :incoming_webhook,
        parameters: params.permit(:object_type, :aspect_type, :object_id, :owner_id, :subscription_id).to_h
          .merge(updates: params["updates"]&.to_unsafe_h)
      )
    end
    head :ok
  end
end
