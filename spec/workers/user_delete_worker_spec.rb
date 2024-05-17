require "rails_helper"

RSpec.describe UserDeleteWorker, type: :job do
  let(:instance) { described_class.new }

  let!(:user) { FactoryBot.create(:user_confirmed, email: "owner1@A.COM") }
  let!(:bike) { FactoryBot.create(:bike, :with_ownership, user: user, creator: user) }

  before { Sidekiq::Worker.clear_all }

  describe "perform" do
    it "soft deletes the user and the user's bikes" do
      expect(User.count).to eq 1
      expect(Bike.count).to eq 1
      expect(UserEmail.count).to eq 1
      instance.perform(user.id)
      expect(User.count).to eq 0
      expect(Bike.count).to eq 0
      expect(UserEmail.count).to eq 0

      expect(User.unscoped.count).to eq 1
      expect(Bike.unscoped.count).to eq 1
    end

    it "allows creating the user again" do
      instance.perform(user.id)

      expect(FactoryBot.create(:user_confirmed, email: "owner1@A.COM")).to be_valid
    end
  end
end
