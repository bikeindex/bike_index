require "rails_helper"

RSpec.describe StripeSubscription, type: :model do
  it_behaves_like "active_periodable"

  describe "factory" do
    let(:stripe_subscription) { FactoryBot.create(:stripe_subscription) }
    it "is valid" do
      expect(stripe_subscription).to be_valid
      expect(stripe_subscription.membership.user_id).to eq stripe_subscription.user_id
      expect(stripe_subscription.user.reload.membership_active&.id).to eq stripe_subscription.membership.id
    end
  end

  describe "update_membership!" do
    let(:stripe_subscription) { FactoryBot.create(:stripe_subscription, membership_id:, start_at:, end_at:, user:) }
    let(:start_at) { Time.current - 1.minute }
    let(:end_at) { nil }
    let(:membership_id) { nil }
    let(:user) { FactoryBot.create(:user_confirmed) }

    context "with existing admin_managed membership" do
      let!(:membership_existing) do
        FactoryBot.create(:membership, user:, start_at: start_at_existing, end_at: end_at_existing,
          creator: FactoryBot.create(:admin))
      end
      let(:start_at_existing) { Time.current - 1.year }
      let(:end_at_existing) { nil }
      let(:target_attrs) do
        {start_at:, end_at:, user_id: user.id, kind: "basic", stripe_managed?: true}
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
        expect(stripe_subscription.membership).to match_hash_indifferently target_attrs
      end
      context "with stripe_subscription ended" do
        let(:start_at) { Time.current - 1.year }
        let(:end_at) { Time.current - 1.week }
        it "does not end the membership" do
          expect(membership_existing.reload.active?).to be_truthy
          expect(stripe_subscription.reload.active?).to be_falsey
          expect(stripe_subscription.membership_id).to be_blank
          stripe_subscription.update_membership!
          expect(membership_existing.reload.active?).to be_truthy
          expect(stripe_subscription.reload.active?).to be_falsey
          expect(stripe_subscription.membership_id).to be_blank
        end
      end
    end
  end
end
