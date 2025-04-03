require "rails_helper"

RSpec.describe WebhooksController, type: :request do
  let(:re_record_interval) { 30.days }

  describe "POST stripe" do
    let(:webhook_url) { "/webhooks/stripe" }
    let(:payload) { File.read(Rails.root.join("spec/fixtures/stripe_webhook-checkout.session.completed.json")) }
    let(:stripe_signature) { generate_stripe_signature(payload) }

    # Helper method to generate a valid Stripe signature for testing
    def generate_stripe_signature(payload)
      timestamp = Time.now.to_i
      secret = ENV["STRIPE_WEBHOOK_SECRET"]
      signed_payload = "#{timestamp}.#{payload}"
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)
      "t=#{timestamp},v1=#{signature}"
    end

    context "with subscription checkout session completed" do
      let(:target_stripe_subscription) do
        {
          user_id: nil,
          stripe_status: "canceled",
          email: "seth@bikeindex.org"
        }
      end
      it "processes the webhook successfully" do
        VCR.use_cassette("WebhooksController-checkout_session-completed", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect do
            post webhook_url,
              params: payload,
              headers: {"CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => stripe_signature}
          end.to change(StripeEvent, :count).by 1

          expect(response).to have_http_status(:ok)
          expect(json_result).to eq({"success" => true})
          stripe_event = StripeEvent.last
          expect(stripe_event.name).to eq "checkout.session.completed"
          expect(stripe_event.stripe_id).to be_present
          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription.start_at).to be_within(1).of Time.at(1740173835) # has to be updated when cassette is updated
          expect(stripe_subscription.end_at).to be_within(1).of Time.at(1742593035)
          expect(stripe_subscription).to match_hash_indifferently target_stripe_subscription
          expect(stripe_subscription.stripe_id).to be_present
          expect(stripe_subscription.membership_id).to be_blank
          expect(stripe_subscription.payments.count).to eq 1
        end
      end
    end

    context "with a stripe subscription created event" do
      let(:payload) { File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.created.json")) }
      let(:target_stripe_subscription) do
        {
          user_id: nil,
          stripe_status: "active",
          email: "seth@bikeindex.org",
          end_at: nil
        }
      end
      include_context :test_csrf_token
      it "processes the webhook successfully" do
        VCR.use_cassette("WebhooksController-subscription-created", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect do
            post webhook_url,
              params: payload,
              headers: {"CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => stripe_signature}
          end.to change(StripeEvent, :count).by 1

          expect(response).to have_http_status(:ok)
          expect(json_result).to eq({"success" => true})
          stripe_event = StripeEvent.last
          expect(stripe_event.name).to eq "customer.subscription.created"
          expect(stripe_event.stripe_id).to be_present
          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription.start_at).to be_within(1).of Time.at(1740173835) # has to be updated when cassette is updated
          expect(stripe_subscription).to match_hash_indifferently(email: nil, stripe_status: "incomplete")
          expect(stripe_subscription.stripe_id).to be_present
          expect(stripe_subscription.membership_id).to be_blank
          expect(stripe_subscription.payments.count).to eq 0
        end
      end
    end

    context "subscription canceled" do
      let(:payload) { File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.updated-canceled.json")) }
      let!(:user) { FactoryBot.create(:user_confirmed, email: "seth@bikeindex.org", stripe_id: "cus_RohIc4uZhMPzxN") }

      it "updates the subscription" do
        VCR.use_cassette("WebhooksController-subscription-cancel", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect do
            post webhook_url,
              params: payload,
              headers: {"CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => stripe_signature}

            expect(response).to have_http_status(:ok)
            expect(json_result).to eq({"success" => true})
          end.to change(StripeEvent, :count).by 1
        end

        stripe_subscription = StripeSubscription.last
        expect(stripe_subscription.user_id).to eq user.id
        expect(stripe_subscription.stripe_status).to eq "active"
        expect(stripe_subscription.start_at).to be_within(1).of Time.at(1740173835)
        expect(stripe_subscription.end_at).to be_within(1).of Time.at(1742593035)

        expect(stripe_subscription.payments.count).to eq 0 # no data to create from
        expect(stripe_subscription.membership_id).to be_present

        membership = stripe_subscription.membership
        expect(membership.user_id).to eq user.id
        expect(membership.start_at).to be_within(1).of stripe_subscription.start_at
        expect(membership.end_at).to be_within(1).of stripe_subscription.end_at
        expect(membership.status).to eq "ended"
      end
    end

    context "with invalid signature" do
      it "returns a 400 bad request status" do
        allow(Stripe::Webhook).to receive(:construct_event).and_raise(Stripe::SignatureVerificationError.new("", ""))

        post webhook_url,
          params: payload,
          headers: {"CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "invalid_signature"}

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "unknown event type" do
      it "returns 400"
    end
  end
end
