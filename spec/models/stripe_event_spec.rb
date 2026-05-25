require "rails_helper"

RSpec.describe StripeEvent, type: :model do
  let(:cassette_options) { {match_requests_on: [:method], re_record_interval: 12.months} }

  describe "update_bike_index_record!" do
    let(:event_mock) do
      # Just uses openstruct, not stripe, but good enough for now
      object = OpenStruct.new(webhook_payload.dig("data", "object"))

      OpenStruct.new(:type => webhook_payload["type"], "data" => {"object" => object})
    end
    let(:stripe_event) { StripeEvent.create_from(event_mock) }
    let!(:stripe_price) { FactoryBot.create(:stripe_price_plus) }

    context "subscription stripe_checkout completed" do
      # Need to re-record Stripe cassettes?
      # 1. Run Stripe::UpdatePricesJob.new.perform in console to add the Stripe dev prices
      # 2. Go to /memberships/new and purchase a plus membership
      # 3. Go to Stripe workbench webhooks
      # 4. Copy in the webhook fixtures
      # Update webhooks_request_spec with anything that changed in the fixtures
      let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-checkout.session.completed.json"))) }
      let(:start_at) { Time.at(1779728250) } # has to be updated when fixture is updated
      let(:email) { "test@example.bikeindex.org" } # Also update if using a different email
      let(:target_subscription) do
        {
          email:,
          stripe_status: "active",
          stripe_price_stripe_id: stripe_price.stripe_id,
          end_at: nil,
          membership_level: "plus",
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
        expect(stripe_subscription).to have_attributes_with_time_within target_subscription
        expect(stripe_subscription.start_at).to be_within(1).of start_at
        expect(stripe_subscription.stripe_id).to be_present
        expect(stripe_subscription.payments.count).to eq 1

        expect(payment).to have_attributes target_payment
        expect(payment.paid_at).to be_present
      end

      it "creates a payment and a stripe subscription" do
        expect(stripe_event).to be_valid
        expect(stripe_event.checkout?).to be_truthy

        VCR.use_cassette("StripeEvent-update_bike_index-success", **cassette_options) do
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
            VCR.use_cassette("StripeEvent-update_bike_index-success", **cassette_options) do
              stripe_event.update_bike_index_record!
            end
            VCR.use_cassette("StripeEvent-update_bike_index-success", **cassette_options) do
              stripe_event.update_bike_index_record!
            end
          end.to change(StripeSubscription, :count).by(1)
            .and change(Payment, :count).by 1

          expect_stripe_subscription_and_payment_to_match_targets(StripeSubscription.last, Payment.last)
        end
      end

      context "with user matching email" do
        let!(:user) { FactoryBot.create(:user_confirmed, email:) }
        let(:target_membership) do
          {level: "plus", status: "active", user_id: user.id}
        end

        it "assigns things to the user and creates a membership" do
          VCR.use_cassette("StripeEvent-update_bike_index-success", **cassette_options) do
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
          expect(membership).to have_attributes_with_time_within target_membership
          expect(membership.start_at).to be_within(1).of start_at
        end

        context "with a matching payment" do
          let(:stripe_subscription) { StripeSubscription.create(user:) }
          let(:checkout_id) { "cs_test_a1XzIICn9NZ2p5RoNzP8GLCSMog4c2noU1G4d4V8sgs3MVjZxEYysztFHl" }
          let!(:payment) do
            stripe_subscription.payments.create(
              stripe_subscription.send(:payment_attrs).merge(stripe_id: checkout_id)
            )
          end
          it "uses the existing subscription" do
            Sidekiq::Job.drain_all
            ActionMailer::Base.deliveries = []

            VCR.use_cassette("StripeEvent-update_bike_index-success", **cassette_options) do
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

      context "subscription deleted" do
        # Optionally, update this fixture by:
        # Cancel the subscription via the Stripe dashboard and update the customer.subscription.deleted webhook fixture
        let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.deleted.json"))) }
        let!(:user) { FactoryBot.create(:user_confirmed, email:) }
        # Stripe subscription ID is required so the existing subscription is updated
        let(:stripe_id) { "sub_0Tb1okm0T0GBfX0vIuafkiOk" }
        let(:end_at) { Time.at(1779739560) } # Update if fixture is updated
        let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription, user:, stripe_id:) }
        let(:target_subscription) do
          {
            email:,
            user_id: user.id,
            stripe_status: "canceled",
            stripe_price_stripe_id: stripe_price.stripe_id,
            membership_level: "plus",
            interval: "monthly",
            test?: true,
            stripe_id:
          }
        end
        it "updates the subscription" do
          expect do
            stripe_event.update_bike_index_record!
          end.to change(StripeSubscription, :count).by 0

          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription).to have_attributes target_subscription

          expect(stripe_subscription.payments.count).to eq 0
          expect(stripe_subscription.membership_id).to be_present
          expect(stripe_subscription.start_at).to be_within(1).of start_at
          expect(stripe_subscription.end_at).to be_within(1).of end_at

          membership = stripe_subscription.membership
          expect(membership.user_id).to eq user.id
          expect(membership.start_at).to be_within(1).of stripe_subscription.start_at
          expect(membership.end_at).to be_within(1).of stripe_subscription.end_at
          expect(membership.status).to eq "ended"
        end
      end
    end

    context "subscription updated (currency CAD)" do
      # Update these cassettes
      # 0. Sign in as a new user
      # 1. Go to /membership/new?currency=cad and purchase a membership
      # 2. update the subscription.updated-cad fixture
      # 3. Get the payment (via /admin/paments and find in console), then run payment.update_from_stripe!
      # 4. Do payment.stripe_subscription.update_from_stripe! as well
      # 5. Verify that the user gets redirected to Stripe when you visit /membership/edit
      # 6. Cancel the membership
      let(:start_at) { Time.at(1779743428) }
      let!(:stripe_price) { FactoryBot.create(:stripe_price, interval: "monthly", amount_cents: 499, currency: "cad", stripe_id: "price_0Qs5rim0T0GBfX0vJClxbae3") }
      let(:email) { "canada@bikeindex.org" }
      context "currency CAD" do
        let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.updated-cad.json"))) }

        it "uses currency" do
          expect do
            stripe_event.update_bike_index_record!
          end.to change(StripeSubscription, :count).by 1

          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription.stripe_price_stripe_id).to eq stripe_price.stripe_id
          expect(stripe_subscription.stripe_status).to eq "active"
          expect(stripe_subscription.user_id).to be_blank
          expect(stripe_subscription.membership_id).to be_blank
          expect(stripe_subscription.start_at).to be_within(1).of start_at
          expect(stripe_subscription.end_at).to be_blank
          expect(stripe_subscription.payments.count).to eq 0
        end
      end

      context "subscription canceled" do
        let(:webhook_payload) { JSON.parse(File.read(Rails.root.join("spec/fixtures/stripe_webhook-customer.subscription.updated-canceled.json"))) }
        let!(:user) { FactoryBot.create(:user_confirmed, email:) }
        let(:stripe_id) { "sub_0Tb5lYm0T0GBfX0vaZSYvmP7" }
        let(:end_at) { Time.at(1782421828) } # cancel_at from the fixture
        let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription, user:, stripe_id:) }
        let(:target_subscription) do
          {
            email:,
            user_id: user.id,
            stripe_status: "active",
            stripe_price_stripe_id: stripe_price.stripe_id,
            membership_level: "basic",
            interval: "monthly",
            currency_enum: "cad",
            test?: true,
            stripe_id: # sanity check. Manually set, needs to be pulled from the cassette
          }
        end
        # When you initially record, the cancellation is in the future
        let(:target_status) { (Time.current > end_at) ? "ended" : "active" }
        it "updates the subscription" do
          # Don't re-record to prevent having to update tests
          expect do
            stripe_event.update_bike_index_record!
          end.to change(StripeSubscription, :count).by 0

          stripe_subscription = StripeSubscription.last
          expect(stripe_subscription).to have_attributes target_subscription

          expect(stripe_subscription.payments.count).to eq 0
          expect(stripe_subscription.membership_id).to be_present
          expect(stripe_subscription.start_at).to be_within(1).of start_at

          expect(stripe_subscription.end_at).to be_within(1).of end_at

          membership = stripe_subscription.membership
          expect(membership.user_id).to eq user.id
          expect(membership.start_at).to be_within(1).of stripe_subscription.start_at
          expect(membership.end_at).to be_within(1).of stripe_subscription.end_at
          expect(membership.status).to eq target_status
        end
      end
    end
  end
end
