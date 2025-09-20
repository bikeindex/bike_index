require "rails_helper"

RSpec.describe Users::CreateOrUpdateMembershipFromPaymentJob, type: :job do
  let(:instance) { described_class.new }

  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:amount_cents) { 999 }
  let(:payment) { FactoryBot.create(:payment, amount_cents:, user:, paid_at: 1.day.ago) }
  let(:creator_id) { FactoryBot.create(:superuser).id }

  let(:new_attrs) do
    {user_id: user.id, start_at: Time.current, end_at: 3.month.from_now,
     creator_id:, level: "basic", status: "active"}
  end
  it "creates a membership" do
    expect(payment.reload.membership_id).to be_blank
    expect(payment.kind).to eq "donation"
    expect {
      instance.perform(payment.id, creator_id)
    }.to change(Membership, :count).by(1)
    expect(payment.reload.membership_id).to be_present
    expect(payment.kind).to eq "donation" # Doesn't update payment kind

    expect(payment.membership).to match_hash_indifferently new_attrs
  end

  context "when payment already has a membership_id" do
    before { payment.update(membership_id: 12) }
    it "does nothing" do
      expect(payment.reload.membership_id).to eq 12
      expect {
        instance.perform(payment.id, 42)
      }.to change(Membership, :count).by(0)
      expect(payment.reload.membership_id).to eq 12
    end
  end

  context "when amount is for $99" do
    let(:amount_cents) { 9999 }
    it "creates a membership" do
      expect(payment.reload.membership_id).to be_blank
      expect(payment.kind).to eq "donation"
      expect {
        instance.perform(payment.id, creator_id)
      }.to change(Membership, :count).by(1)
      expect(payment.reload.membership_id).to be_present
      expect(payment.kind).to eq "donation" # Doesn't update payment kind

      expect(payment.membership).to match_hash_indifferently new_attrs.merge(level: "patron", end_at: 1.year.from_now)
    end
  end

  context "when user already has a membership" do
    let!(:membership) { FactoryBot.create(:membership, start_at:, end_at:, level: "plus", user_id: user.id) }
    let(:start_at) { 1.month.ago }
    let(:end_at) { 2.months.from_now }
    let(:new_end_at) { end_at + 3.months }
    let(:updated_attrs) do
      {user_id: user.id, start_at:, end_at: end_at + 3.months,
       creator_id: membership.creator_id, level: "plus", status: "active"}
    end
    it "extends the membership" do
      expect(membership.reload.creator_id).to_not eq creator_id
      expect(membership.status).to eq "active"
      expect(payment.reload.membership_id).to be_blank
      expect(payment.kind).to eq "donation"
      expect {
        instance.perform(payment.id, creator_id)
      }.to change(Membership, :count).by(0)
      expect(payment.reload.membership_id).to eq membership.id
      expect(payment.kind).to eq "donation" # Doesn't update payment kind

      expect(membership.reload).to match_hash_indifferently updated_attrs
    end

    context "when the membership ended" do
      let(:end_at) { 1.day.ago }
      it "creates a new membership from today" do
        expect(membership.reload.creator_id).to_not eq creator_id
        expect(membership.status).to eq "ended"
        expect {
          instance.perform(payment.id, creator_id)
        }.to change(Membership, :count).by(1)
        expect(payment.reload.membership_id).to_not eq membership.id
        expect(payment.kind).to eq "donation" # Doesn't update payment kind

        expect(payment.membership).to match_hash_indifferently new_attrs
      end
    end
  end
end
