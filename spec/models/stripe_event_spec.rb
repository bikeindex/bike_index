require "rails_helper"

RSpec.describe StripeEvent, type: :model do
  let(:re_record_interval) { 30.days }

  describe "update_bike_index_record" do
    let(:event_mock) do
      # Just uses openstruct, not stripe, but good enough for now
      object = OpenStruct.new(webhook_payload.dig("data", "object"))

      OpenStruct.new(:type => webhook_payload["type"], "data" => {"object" => object})
    end
    let(:stripe_event) { StripeEvent.create_from(event_mock) }

    context "subscription stripe_checkout completed" do
      let!(:stripe_price) { FactoryBot.create(:stripe_price_plus) }
      let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-checkout.session.completed.json"))) }
      let(:start_at) { Time.at(1740173835) } # has to be updated when fixture is updated
      let(:target_subscription) do
        {
          email: "seth@bikeindex.org",
          stripe_status: "active",
          stripe_price_stripe_id: stripe_price.stripe_id,
          end_at: nil,
          membership_kind: "plus",
          interval: "monthly",
          test?: true
        }
      end
      let(:target_payment) do
        {
          kind: "membership_donation",
          payment_method: "stripe",
          stripe_subscription?: true,
          amount_cents: 999,
          currency_enum: "usd"
        }
      end

      def expect_stripe_subscription_and_payment_to_match_targets(stripe_subscription, payment)
        expect(stripe_subscription).to match_hash_indifferently target_subscription
        expect(stripe_subscription.start_at).to be_within(1).of start_at
        expect(stripe_subscription.stripe_id).to be_present
        expect(stripe_subscription.payments.count).to eq 1

        expect(payment).to match_hash_indifferently target_payment
        expect(payment.paid_at).to be_present
      end


      it "creates a payment and a stripe subscription" do
        expect(stripe_event).to be_valid
        expect(stripe_event.checkout?).to be_truthy

        VCR.use_cassette("StripeEvent-update_bike_index-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
          expect do
            stripe_event.update_bike_index_record
          end.to change(StripeSubscription, :count).by 1
        end

        stripe_subscription = StripeSubscription.last
        payment = Payment.last
        expect_stripe_subscription_and_payment_to_match_targets(stripe_subscription, payment)

        expect(stripe_subscription.user_id).to be_blank
        expect(stripe_subscription.membership_id).to be_blank
        expect(payment.user_id).to be_blank
      end

      context "calling it twice doesn't do anything different" do

      end

      context "with user matching email" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: "seth@bikeindex.org") }
        let(:target_membership) do
          {kind: "plus", status: "status_active", user_id: user.id, end_at: nil, active: true}
        end

        it "assigns things to the user and creates a membership" do
          VCR.use_cassette("StripeEvent-update_bike_index-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
            expect do
              stripe_event.update_bike_index_record
            end.to change(StripeSubscription, :count).by 1
          end

          stripe_subscription = StripeSubscription.last
          payment = Payment.last
          expect_stripe_subscription_and_payment_to_match_targets(stripe_subscription, payment)

          expect(stripe_subscription.user_id).to eq user.id
          expect(stripe_subscription.membership_id).to be_present
          expect(payment.user_id).to eq user.id

          membership = stripe_subscription.membership
          expect(membership).to match_hash_indifferently target_membership
          expect(membership.start_at).to be_within(1).of start_at
        end
      end

      context "currency CAD" do
        it "uses currency"
      end
    end
  end
end
