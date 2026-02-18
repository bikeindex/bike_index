require "rails_helper"

RSpec.describe StripeSubscription, type: :model do
  it_behaves_like "active_periodable"

  let(:re_record_interval) { 60.days }

  describe "factory" do
    let(:stripe_subscription) { FactoryBot.create(:stripe_subscription) }
    it "is valid" do
      expect(stripe_subscription).to be_valid
      expect(stripe_subscription.membership.user_id).to eq stripe_subscription.user_id
      expect(stripe_subscription.membership.admin_managed?).to be_falsey
      expect(stripe_subscription.user.reload.membership_active&.id).to eq stripe_subscription.membership.id
    end
  end

  describe "create_for" do
    let(:stripe_price) { FactoryBot.create(:stripe_price_basic_yearly) }
    let(:user) { FactoryBot.create(:user_confirmed) }

    it "creates a stripe_subscription" do
      VCR.use_cassette("StripeSubscription-create_for-success", match_requests_on: [:method], re_record_interval:) do
        stripe_subscription = StripeSubscription.create_for(stripe_price:, user:)
        expect(stripe_subscription).to be_valid
        expect(stripe_subscription.stripe_checkout_session_url).to be_present
        expect(stripe_subscription.payments.count).to eq 1
        expect(stripe_subscription.stripe_status).to be_blank
        expect(stripe_subscription.referral_source).to be_blank

        payment = stripe_subscription.payments.first
        expect(payment.referral_source).to be_blank
        expect(payment.stripe_status).to be_blank

        # Calling fetch_stripe_checkout_session_url doesn't create again
        stripe_subscription.reload.fetch_stripe_checkout_session_url
        expect(stripe_subscription.reload.payments.count).to eq 1
      end
    end
    context "with a referral_source" do
      it "creates a stripe_subscription" do
        VCR.use_cassette("StripeSubscription-create_for-success", match_requests_on: [:method], re_record_interval:) do
          stripe_subscription = StripeSubscription.create_for(stripe_price:, user:, referral_source: "some-referral")
          expect(stripe_subscription).to be_valid
          expect(stripe_subscription.stripe_checkout_session_url).to be_present
          expect(stripe_subscription.payments.count).to eq 1
          expect(stripe_subscription.stripe_status).to be_blank
          expect(stripe_subscription.referral_source).to eq("some-referral")

          payment = stripe_subscription.payments.first
          expect(payment.referral_source).to eq "some-referral"
          expect(payment.stripe_status).to be_blank
          expect(payment.kind).to eq "membership_donation"

          # Calling fetch_stripe_checkout_session_url doesn't create again
          stripe_subscription.reload.fetch_stripe_checkout_session_url
          expect(stripe_subscription.reload.payments.count).to eq 1
        end
      end
    end

    context "user has an invalid stripe_id" do
      let(:user) { FactoryBot.create(:user_confirmed, stripe_id: "cus_xxxx") }
      it "creates a stripe_subscription" do
        VCR.use_cassette("StripeSubscription-create_for-invalid_user_id", match_requests_on: [:method], re_record_interval:) do
          stripe_subscription = StripeSubscription.create_for(stripe_price:, user:)
          expect(stripe_subscription).to be_valid
          expect(stripe_subscription.stripe_checkout_session_url).to be_present
          expect(stripe_subscription.payments.count).to eq 1
        end
      end
    end
  end

  describe "update_membership!" do
    let(:stripe_subscription) { FactoryBot.create(:stripe_subscription, membership_id:, start_at:, end_at:, user:, stripe_status:) }
    let(:start_at) { Time.current - 1.minute }
    let(:end_at) { nil }
    let(:membership_id) { nil }
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:stripe_status) { "active" }

    context "with existing admin_managed membership" do
      let!(:membership_existing) do
        FactoryBot.create(:membership, user:, start_at: start_at_existing, end_at: end_at_existing,
          creator: FactoryBot.create(:superuser))
      end
      let(:start_at_existing) { Time.current - 1.year }
      let(:end_at_existing) { nil }
      let(:target_attrs) do
        {start_at:, end_at:, user_id: user.id, level: "basic", stripe_managed?: true}
      end

      it "ends the membership and creates a new one" do
        expect(membership_existing.reload.active?).to be_truthy
        expect(membership_existing.admin_managed?).to be_truthy
        expect(stripe_subscription.reload.active?).to be_truthy
        expect(stripe_subscription.membership).to be_blank
        stripe_subscription.update_membership!
        expect(membership_existing.reload.active?).to be_falsey
        expect(membership_existing.end_at).to be_within(1).of start_at
        expect(membership_existing.admin_managed?).to be_truthy
        expect(stripe_subscription.reload.active?).to be_truthy
        expect(stripe_subscription.membership_id).to be_present
        expect(stripe_subscription.membership).to have_attributes target_attrs
      end

      context "with stripe_subscription ended" do
        let(:stripe_status) { "ended" }
        let(:start_at) { Time.current - 1.year }
        let(:end_at) { Time.current - 1.week }
        it "does not end the membership" do
          expect(membership_existing.reload.active?).to be_truthy
          expect(stripe_subscription.reload.active?).to be_falsey
          expect(stripe_subscription.membership_id).to be_blank
          stripe_subscription.update_membership!
          expect(membership_existing.reload.active?).to be_truthy
          expect(stripe_subscription.reload.active?).to be_falsey
          expect(stripe_subscription.membership_id).to be_present
          expect(stripe_subscription.membership_id).to_not eq membership_existing.id
        end
      end
    end

    context "ended" do
      let(:start_at) { Time.current - 1.year }
      let(:end_at) { Time.current - 1.minute }
      let(:stripe_status) { "canceled" }
      let(:target_attrs) { {start_at:, end_at:, level: "basic", status: "ended"} }

      it "creates a membership and ends it" do
        expect(stripe_subscription.reload.active?).to be_falsey
        expect(stripe_subscription.membership).to be_blank
        stripe_subscription.update_membership!
        expect(stripe_subscription.reload.active?).to be_falsey
        expect(stripe_subscription.membership_id).to be_present
        expect(stripe_subscription.membership).to have_attributes target_attrs
      end

      context "with existing membership" do
        let(:membership) { FactoryBot.create(:membership, user:, start_at: start_at, end_at: nil) }
        let(:membership_id) { membership.id }

        it "ends the membership" do
          expect(stripe_subscription.reload.active?).to be_falsey
          expect(stripe_subscription.membership_id).to eq membership.id
          expect(membership.reload.active?).to be_truthy
          stripe_subscription.update_membership!
          expect(stripe_subscription.reload.active?).to be_falsey
          expect(stripe_subscription.membership_id).to eq membership.id
          expect(membership.reload).to have_attributes target_attrs
        end
      end
    end
  end
end
