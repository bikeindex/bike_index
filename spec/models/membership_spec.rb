require "rails_helper"

RSpec.describe Membership, type: :model do
  it_behaves_like "active_periodable"

  describe "factory" do
    let(:membership) { FactoryBot.create(:membership) }
    it "is valid" do
      expect(membership).to be_valid
      expect(membership.stripe_managed?).to be_falsey
      expect(membership.period_active?).to be_truthy
      expect(membership.status).to eq "active"
    end
    context "stripe_managed" do
      let(:membership) { FactoryBot.create(:membership_stripe_managed) }
      it "is valid" do
        expect(membership).to be_valid
        expect(membership.stripe_managed?).to be_truthy
      end
    end
    context "with_payment" do
      let(:membership) { FactoryBot.create(:membership, :with_payment) }
      let(:payment) { membership.payments.first }
      it "is valid" do
        expect(membership).to be_valid
        expect(membership.reload.user_id).to eq payment.user_id
        expect(membership.payments.count).to eq 1
        expect(membership.stripe_managed?).to be_falsey
        expect(membership.status).to eq "active"

        expect(payment.reload.kind).to eq "membership_donation"
      end
    end
  end

  describe "user_email" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    it "finds the user" do
      expect(user.reload.confirmed?).to be_truthy
      membership = Membership.new(user_email: user.email)
      expect(membership.save).to be_truthy
      expect(membership.reload.user_id).to eq user.id
    end
  end

  describe "validations" do
    let(:creator) { FactoryBot.create(:admin) }
    let!(:membership_existing) { FactoryBot.create(:membership, start_at: Time.current - 2.months, end_at: end_at_existing, creator:) }
    let(:user) { membership_existing.user.reload }
    let(:membership_new) { FactoryBot.build(:membership, start_at: Time.current - 1.week, user:, creator:) }
    let(:end_at_existing) { nil }

    it "blocks creating when there is an existing membership" do
      expect(membership_existing).to be_valid
      expect(membership_new.save).to be_falsey
      expect(membership_new.errors.full_messages.to_s).to match(/prior/)
      expect(membership_new.save).to be_falsey
    end

    context "when updating existing to overlap" do
      let(:end_at_existing) { Time.current - 8.days }
      it "blocks updating" do
        expect(membership_existing.reload.period_active?).to be_falsey
        expect(membership_new.save).to be_truthy
        membership_existing.end_at = nil
        expect(membership_existing.save).to be_falsey
        expect(membership_existing.errors.full_messages.to_s).to match(/prior/)
        expect(membership_existing.save).to be_falsey
      end

      context "when invalid date is set" do
        it "blocks updating the earlier created one" do
          membership_new.save!
          membership_existing.update_columns(end_at: nil, status: "active")
          expect(membership_new.reload.period_active?).to be_truthy
          expect(membership_new.id).to be > membership_existing.id
          membership_existing.reload.save
          expect(membership_existing.reload.save).to be_truthy
          membership_existing.update(end_at: Time.current + 1.minute)
          expect(membership_existing.reload.end_at).to be_within(1).of Time.current + 1.minute

          # Nothing has happened here
          expect(membership_new.reload.end_at).to be_nil
        end
      end
    end
  end

  describe "user member and scope" do
    let(:membership) { FactoryBot.create(:membership) }
    let(:user) { membership.user }
    it "is member" do
      expect(membership.reload.status).to eq "active"
      expect(user.reload.member?).to be_truthy
      expect(User.member.pluck(:id)).to eq([user.id])
    end
    context "membership pending" do
      let(:membership) { FactoryBot.create(:membership, start_at: Time.current + 1.week) }
      it "is not member" do
        expect(membership.reload.status).to eq "pending"
        expect(user.reload.member?).to be_falsey
        expect(User.member.pluck(:id)).to eq([])
      end
    end
    context "membership ended" do
      let(:membership) { FactoryBot.create(:membership, end_at: Time.current - 1) }
      it "is not member" do
        expect(membership.reload.status).to eq "ended"
        expect(user.reload.member?).to be_falsey
        expect(User.member.pluck(:id)).to eq([])
      end
    end
  end

  describe "current_stripe_subscription" do
    let(:membership) { FactoryBot.create(:membership, creator: nil) }
    let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription_active, membership:) }
    it "is the active subscription" do
      expect(membership.reload.current_stripe_subscription&.id).to eq stripe_subscription.id
      expect(membership.current_stripe_subscription.active?).to be_truthy
      expect(membership.stripe_id).to eq stripe_subscription.stripe_id
      expect(membership.stripe_managed?).to be_truthy
      # If there are multiple active subscriptions, return the first
      FactoryBot.create(:stripe_subscription_active, membership:)

      expect(membership.reload.current_stripe_subscription&.id).to eq stripe_subscription.id
      expect(membership.stripe_subscriptions.count).to eq 2
    end

    context "inactive subscription" do
      let!(:stripe_subscription) { FactoryBot.create(:stripe_subscription, membership:) }
      it "is the subscription" do
        expect(membership.reload.current_stripe_subscription&.id).to eq stripe_subscription.id
        expect(membership.current_stripe_subscription.active?).to be_falsey
        expect(membership.stripe_id).to eq stripe_subscription.stripe_id

        # If there are multiple inactive stripe_subscriptions, use the last one
        stripe_subscription_2 = FactoryBot.create(:stripe_subscription, membership:)
        membership = Membership.find stripe_subscription.membership_id # unmemoize variable
        expect(membership.current_stripe_subscription&.id).to eq stripe_subscription_2.id

        # return the active subscription if there is one
        # (update the first one to verify that ID ordering doesn't effect it)
        stripe_subscription.update(stripe_status: "active")
        membership = Membership.find stripe_subscription_2.membership_id # unmemoize variable
        expect(membership.reload.current_stripe_subscription&.id).to eq stripe_subscription.id
        expect(membership.stripe_subscriptions.count).to eq 2
      end
    end
  end
end
