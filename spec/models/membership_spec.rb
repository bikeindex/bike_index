require "rails_helper"

RSpec.describe Membership, type: :model do
  it_behaves_like "active_periodable"

  describe "factory" do
    let(:membership) { FactoryBot.create(:membership) }
    it "is valid" do
      expect(membership).to be_valid
      expect(membership.stripe_managed?).to be_falsey
      expect(membership.active?).to be_truthy
      expect(membership.status).to eq "status_active"
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
        expect(membership.status).to eq "status_active"

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
        expect(membership_existing.reload.active?).to be_falsey
        expect(membership_new.save).to be_truthy
        membership_existing.end_at = nil
        expect(membership_existing.save).to be_falsey
        expect(membership_existing.errors.full_messages.to_s).to match(/prior/)
        expect(membership_existing.save).to be_falsey
      end

      context "when invalid date is set" do
        it "blocks updating the earlier created one" do
          membership_new.save!
          membership_existing.update_columns(end_at: nil, active: true)
          expect(membership_new.reload.active?).to be_truthy
          expect(membership_existing.reload.save).to be_truthy
          membership_existing.update(end_at: Time.current + 1.minute)
          expect(membership_existing.reload.end_at).to be_within(1).of Time.current + 1.minute

          # Nothing has happened here
          expect(membership_new.reload.end_at).to be_nil
        end
      end
    end
  end
end
