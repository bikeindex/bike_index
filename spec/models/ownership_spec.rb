require "rails_helper"

RSpec.describe Ownership, type: :model do
  describe "set_calculated_attributes" do
    it "removes leading and trailing whitespace and downcase email" do
      ownership = Ownership.new(owner_email: "   SomE@dd.com ")
      ownership.set_calculated_attributes
      expect(ownership.owner_email).to eq("some@dd.com")
    end

    it "haves before save callback" do
      expect(Ownership._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_calculated_attributes)).to eq(true)
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
      let(:organization) { FactoryBot.create(:organization) }
      let!(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: organization) }
      let(:bike) { ownership.bike }
      let(:ownership2) { FactoryBot.build(:ownership_organization_bike, organization: organization, bike: bike) }
      it "returns false" do
        organization.update_attribute :paid_feature_slugs, ["skip_ownership_email"]
        ownership.reload
        expect(ownership.first?).to be_truthy
        expect(ownership.calculated_send_email).to be_falsey
        ownership2.save
        ownership2.reload
        expect(ownership2.calculated_send_email).to be_truthy
      end
    end
  end
end
