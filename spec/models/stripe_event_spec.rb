require "rails_helper"

RSpec.describe StripeEvent, type: :model do
  let(:re_record_interval) { 30.days }

  describe "update_bike_index_record!" do
    let(:event_mock) do
      # Just uses openstruct, not stripe, but good enough for now
      object = OpenStruct.new(webhook_payload.dig("data", "object"))

      OpenStruct.new(:type => webhook_payload["type"], "data" => {"object" => object})
    end
    let(:stripe_event) { StripeEvent.create_from(event_mock) }
    let!(:stripe_price) { FactoryBot.create(:stripe_price_plus) }

    context "subscription stripe_checkout completed" do
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
            stripe_event.update_bike_index_record!
          end.to change(StripeSubscription, :count).by 1
        end

        stripe_subscription = StripeSubscription.last
        payment = Payment.last
        expect_stripe_subscription_and_payment_to_match_targets(stripe_subscription, payment)

        expect(stripe_subscription.user_id).to be_blank
        expect(stripe_subscription.membership_id).to be_blank
        expect(payment.user_id).to be_blank
      end

      context "called twice" do
        it "only creates the things once" do
          expect do
            VCR.use_cassette("StripeEvent-update_bike_index-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
              stripe_event.update_bike_index_record!
            end
            VCR.use_cassette("StripeEvent-update_bike_index-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
              stripe_event.update_bike_index_record!
            end
          end.to change(StripeSubscription, :count).by(1)
            .and change(Payment, :count).by 1

          expect_stripe_subscription_and_payment_to_match_targets(StripeSubscription.last, Payment.last)
        end
      end

      context "with user matching email" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: "seth@bikeindex.org") }
        let(:target_membership) do
          {kind: "plus", status: "active", user_id: user.id, end_at: nil}
        end

        it "assigns things to the user and creates a membership" do
          VCR.use_cassette("StripeEvent-update_bike_index-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
            expect do
              stripe_event.update_bike_index_record!
            end.to change(StripeSubscription, :count).by 1
          end

          stripe_subscription = StripeSubscription.last
          payment = Payment.last
          expect_stripe_subscription_and_payment_to_match_targets(stripe_subscription, payment)

          expect(stripe_subscription.user_id).to eq user.id
          expect(stripe_subscription.membership_id).to be_present
          expect(payment.user_id).to eq user.id
          expect(payment.membership_id).to eq stripe_subscription.membership_id

          membership = stripe_subscription.membership
          expect(membership).to match_hash_indifferently target_membership
          expect(membership.start_at).to be_within(1).of start_at
        end

        context "with a matching payment" do
          let(:stripe_subscription) { StripeSubscription.create(user:) }
          let(:checkout_id) { "cs_test_a14VdEixSrpFjwqkENSaSEdr8THKAu5Q6wCe8tE1qJaeBB6NEAsjpYvgg4" }
          let!(:payment) do
            stripe_subscription.payments.create(
              stripe_subscription.send(:payment_attrs).merge(stripe_id: checkout_id)
            )
          end
          it "uses the existing subscription" do
            Sidekiq::Job.drain_all
            ActionMailer::Base.deliveries = []

            VCR.use_cassette("StripeEvent-update_bike_index-success", match_requests_on: [:method], re_record_interval: re_record_interval) do
              expect do
                stripe_event.update_bike_index_record!
              end.to change(StripeSubscription, :count).by 0
            end

            expect_stripe_subscription_and_payment_to_match_targets(stripe_subscription.reload, payment.reload)

            Sidekiq::Job.drain_all
            expect(ActionMailer::Base.deliveries.count).to eq 1 # Should be 2 someday
          end
        end
      end
    end

    context "subscription updated" do
      context "currency CAD" do
        let!(:stripe_price) { FactoryBot.create(:stripe_price, interval: "yearly", amount_cents: 4999, currency: "cad", stripe_id: "price_0Qs61bm0T0GBfX0vjadfNRv8") }
        let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.updated-cad.json"))) }

        it "uses currency" do
          VCR.use_cassette("StripeEvent-update_bike_index-canadian", match_requests_on: [:method], re_record_interval: re_record_interval) do
            expect do
              stripe_event.update_bike_index_record!
            end.to change(StripeSubscription, :count).by 1
          end

          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription.stripe_price_stripe_id).to eq stripe_price.stripe_id
          expect(stripe_subscription.stripe_status).to eq "active"
          expect(stripe_subscription.user_id).to be_blank
          expect(stripe_subscription.membership_id).to be_blank
          expect(stripe_subscription.start_at).to be_within(1).of Time.at(1740271007)
          expect(stripe_subscription.end_at).to be_blank
          expect(stripe_subscription.payments.count).to eq 0
        end
      end

      context "subscription canceled" do
        let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.updated-canceled.json"))) }
        let!(:user) { FactoryBot.create(:user_confirmed, email: "seth@bikeindex.org") }
        let(:stripe_id) { "sub_0Qv3uJm0T0GBfX0v77OTe6ii" }
        let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription, user:, stripe_id:) }
        let(:target_subscription) do
          {
            email: "seth@bikeindex.org",
            user_id: user.id,
            stripe_status: "active",
            stripe_price_stripe_id: stripe_price.stripe_id,
            membership_kind: "plus",
            interval: "monthly",
            test?: true,
            stripe_id: # sanity check. Manually set, needs to be pulled from the cassette
          }
        end
        it "updates the subscription" do
          # Don't re-record to prevent having to update tests
          VCR.use_cassette("StripeEvent-update_bike_index-cancel", match_requests_on: [:method]) do
            expect do
              stripe_event.update_bike_index_record!
            end.to change(StripeSubscription, :count).by 0
          end

          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription).to match_hash_indifferently target_subscription

          expect(stripe_subscription.payments.count).to eq 0
          expect(stripe_subscription.membership_id).to be_present
          expect(stripe_subscription.start_at).to be_within(1).of Time.at(1740173835)
          expect(stripe_subscription.end_at).to be_within(1).of Time.at(1742593035)

          membership = stripe_subscription.membership
          expect(membership.user_id).to eq user.id
          expect(membership.start_at).to be_within(1).of stripe_subscription.start_at
          expect(membership.end_at).to be_within(1).of stripe_subscription.end_at
          expect(membership.status).to eq "active"
        end
      end
    end
  end
end
