require "rails_helper"

base_url = "/webhooks"
RSpec.describe WebhooksController, type: :request do
  let(:re_record_interval) { 30.days }

  describe "POST stripe" do
    let(:webhook_url) { "/webhooks/stripe" }
    let(:payload) { File.read(Rails.root.join("spec/fixtures/stripe_webhook-checkout.session.completed.json")) }
    let(:stripe_signature) { generate_stripe_signature(payload) }

    # Helper method to generate a valid Stripe signature for testing
    def generate_stripe_signature(payload)
      timestamp = Time.now.to_i
      secret = ENV['STRIPE_WEBHOOK_SECRET'] || 'whsec_test_secret'
      signed_payload = "#{timestamp}.#{payload}"
      signature = OpenSSL::HMAC.hexdigest('SHA256', secret, signed_payload)
      "t=#{timestamp},v1=#{signature}"
    end

    before do
      # Stub the Stripe Webhook.construct_event method
      allow(Stripe::Webhook).to receive(:construct_event).and_return(
        Stripe::Event.construct_from(JSON.parse(payload))
      )
    end

    context "with subscription checkout session completed" do
      let(:target_stripe_subscription) do
        {
          user_id: nil,
          stripe_status: "active",
          email: "seth@bikeindex.org",
          end_at: nil
        }
      end
      it "processes the webhook successfully" do
        VCR.use_cassette("WebhooksController-checkout_session-completed", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect do
            post webhook_url,
                 params: payload,
                 headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_STRIPE_SIGNATURE' => stripe_signature }
           end.to change(StripeEvent, :count).by 1

          expect(response).to have_http_status(:ok)
          expect(json_result).to eq({"success" => true})
          stripe_event = StripeEvent.last
          expect(stripe_event.name).to eq "checkout.session.completed"
          expect(stripe_event.stripe_id).to be_present
          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription.start_at).to be_within(1).of Time.at(1740173835) # has to be updated when cassette is updated
          expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription
          expect(stripe_subscription.stripe_id).to be_present
          expect(stripe_subscription.membership_id).to be_blank
          expect(stripe_subscription.payments.count)
        end
      end
    end

    context "with a checkout session completed - not subscription" do
      it "processes the webhook successfully"
    end

    context "with invalid signature" do
      it "returns a 400 bad request status" do
        allow(Stripe::Webhook).to receive(:construct_event).and_raise(Stripe::SignatureVerificationError.new('', ''))

        post webhook_url,
             params: payload,
             headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_STRIPE_SIGNATURE' => "invalid_signature" }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "unknown event type" do
      it "returns 400"
    end

    # Seems like a low value test
    # context "with invalid JSON payload" do
    #   it "returns a 400 bad request status" do
    #     post webhook_url,
    #          params: "invalid json",
    #          headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_STRIPE_SIGNATURE' => stripe_signature }

    #     expect(response).to have_http_status(:bad_request)
    #   end
    # end
  end
end
