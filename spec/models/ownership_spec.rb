require 'spec_helper'

describe Ownership do
  describe 'validations' do
    it { is_expected.to belong_to(:bike).touch true }
    it { is_expected.to belong_to(:user).touch true }
    it { is_expected.to belong_to :creator }
    it { is_expected.to validate_presence_of :creator_id }
    it { is_expected.to validate_presence_of :bike_id }
    it { is_expected.to validate_presence_of :owner_email }
  end

  describe 'normalize_email' do
    it 'removes leading and trailing whitespace and downcase email' do
      ownership = Ownership.new
      allow(ownership).to receive(:owner_email).and_return('   SomE@dd.com ')
      expect(ownership.normalize_email).to eq('some@dd.com')
    end

    it 'haves before save callback' do
      expect(Ownership._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_email)).to eq(true)
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

  describe 'owner' do
    it 'returns the current owner if the ownership is claimed' do
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

    it 'returns auto user if creator is deleted' do
      user = FactoryBot.create(:user_confirmed, email: ENV['AUTO_ORG_MEMBER'])
      ownership = Ownership.new
      expect(ownership.owner).to eq(user)
    end
  end

  describe 'can_be_claimed_by' do
    let(:user) { FactoryBot.create(:user_confirmed) }
    it 'true if user email matches' do
      ownership = Ownership.new(owner_email: " #{user.email.upcase}")
      expect(ownership.can_be_claimed_by(user)).to be_truthy
    end
    it 'true if user matches' do
      ownership = Ownership.new(user_id: user.id)
      expect(ownership.can_be_claimed_by(user)).to be_truthy
    end
    it "false if it can't be claimed by user" do
      ownership = Ownership.new(owner_email: "fake#{user.email.titleize}")
      expect(ownership.can_be_claimed_by(user)).to be_falsey
    end
  end
end
