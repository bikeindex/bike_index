require "rails_helper"

RSpec.describe Ownership, type: :model do
  describe "set_calculated_attributes" do
    it "removes leading and trailing whitespace and downcase email" do
      ownership = Ownership.new(owner_email: "   SomE@dd.com ")
      ownership.set_calculated_attributes
      expect(ownership.owner_email).to eq("some@dd.com")
    end
  end

  describe "validate owner_email format" do
    it "disallows owner_emails without an @ sign" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "n/a")
      expect(ownership).to_not be_valid
      expect(ownership.errors.full_messages).to eq(["Owner email invalid format"])
    end

    it "disallows owner_emails without a tld" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "name@email")
      expect(ownership).to_not be_valid
      expect(ownership.errors.full_messages).to eq(["Owner email invalid format"])
    end

    it "disallows owner_emails without a mailbox" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "@email.com")
      expect(ownership).to_not be_valid
      expect(ownership.errors.full_messages).to eq(["Owner email invalid format"])
    end

    it "allows owner_emails with valid modifications" do
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "name.1@email.com")
      expect(ownership).to be_valid
      ownership = FactoryBot.build_stubbed(:ownership, owner_email: "name+two@email.com")
      expect(ownership).to be_valid
    end
  end

  describe "mark_claimed" do
    it "associates with a user" do
      ownership = FactoryBot.create(:ownership)
      ownership.mark_claimed
      expect(ownership.claimed?).to be_truthy
    end
    context "factory ownership_claimed" do
      let!(:ownership) { FactoryBot.create(:ownership_claimed) }
      it "is claimed" do
        expect(ownership.claimed?).to be_truthy
      end
    end
  end

  describe "owner" do
    it "returns the current owner if the ownership is claimed" do
      user = FactoryBot.create(:user_confirmed)
      ownership = Ownership.new
      allow(ownership).to receive(:claimed).and_return(true)
      allow(ownership).to receive(:user).and_return(user)
      expect(ownership.owner).to eq(user)
    end

    it "returns the creator if it isn't claimed" do
      user = FactoryBot.create(:user_confirmed)
      ownership = Ownership.new
      allow(ownership).to receive(:claimed).and_return(false)
      allow(ownership).to receive(:creator).and_return(user)
      expect(ownership.owner).to eq(user)
    end

    it "returns auto user if creator is deleted" do
      user = FactoryBot.create(:user_confirmed, email: ENV["AUTO_ORG_MEMBER"])
      ownership = Ownership.new
      expect(ownership.owner).to eq(user)
    end
  end

  describe "claimable_by?" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    it "true if user email matches" do
      ownership = Ownership.new(owner_email: " #{user.email.upcase}")
      expect(ownership.claimable_by?(user)).to be_truthy
    end
    it "true if user matches" do
      ownership = Ownership.new(user_id: user.id)
      expect(ownership.claimable_by?(user)).to be_truthy
    end
    it "false if it can't be claimed by user" do
      ownership = Ownership.new(owner_email: "fake#{user.email.titleize}")
      expect(ownership.claimable_by?(user)).to be_falsey
    end
  end

  describe "calculated_send_email" do
    let(:bike) { Bike.new }
    it "is true" do
      expect(Ownership.new(bike: bike).calculated_send_email).to be_truthy
    end
    context "send email is false" do
      it "is false" do
        expect(Ownership.new(send_email: false, bike: bike).calculated_send_email).to be_falsey
      end
    end
    context "example bike" do
      let(:bike) { Bike.new(example: true) }
      let(:ownership) { Ownership.new(bike: bike) }
      it "is false" do
        expect(ownership.calculated_send_email).to be_falsey
      end
    end
    context "organization with paid feature of skip_ownership_email" do
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["skip_ownership_email"]) }
      let!(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: organization) }
      let(:bike) { ownership.bike }
      it "returns false" do
        # There was some trouble with CI on this, so now we're just updating a bunch
        ownership.update(updated_at: Time.current)
        expect(organization.enabled?("skip_ownership_email")).to be_truthy
        expect(ownership.first?).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
        ownership2 = FactoryBot.create(:ownership, bike: bike, created_at: Time.current)
        ownership2.update(updated_at: Time.current)
        ownership2.reload
        expect(ownership2.organization).to be_blank
        expect(ownership2.calculated_send_email).to be_truthy
      end
    end
  end

  describe "spam_risky_email?" do
    # hotmail and yahoo have been delaying our emails. In an effort to ensure delivery of really important emails (e.g. password resets)
    # skip sending ownership invitations for POS registrations, just in case
    let(:bike) { Bike.new(owner_email: email) }
    let(:ownership) { Ownership.new(bike: bike, owner_email: email) }
    let(:creation_state) { CreationState.new(pos_kind: pos_kind) }
    let(:pos_kind) { "lightspeed_pos" }
    before { allow(bike).to receive(:creation_state) { creation_state } }
    context "gmail email" do
      let(:email) { "test@gmail.com" }
      it "false, calculated_send_email: true" do
        expect(ownership.send(:spam_risky_email?)).to be_falsey
        expect(ownership.calculated_send_email).to be_truthy
      end
    end
    context "yahoo email" do
      let(:email) { "test@yahoo.com" }
      it "does not send" do
        expect(ownership.send(:spam_risky_email?)).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
      end
      context "yahoo.co" do
        let(:email) { "example@yahoo.co" } # I don't know if these are typos or it's separate, but skip it nonetheless
        it "does not send" do
          expect(ownership.send(:spam_risky_email?)).to be_truthy
          expect(ownership.calculated_send_email).to be_falsey
        end
      end
      context "not pos registration" do
        let(:pos_kind) { "does_not_need_pos" }
        it "sends" do
          expect(ownership.send(:spam_risky_email?)).to be_falsey
          expect(ownership.calculated_send_email).to be_truthy
        end
      end
    end
    context "hotmail email" do
      let(:email) { "test@hotmail.com" }
      let(:pos_kind) { "ascend_pos" }
      it "does not send" do
        expect(ownership.send(:spam_risky_email?)).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
      end
      context "not pos registration" do
        let(:pos_kind) { "no_pos" }
        it "sends" do
          expect(ownership.send(:spam_risky_email?)).to be_falsey
          expect(ownership.calculated_send_email).to be_truthy
        end
      end
    end
  end
end
