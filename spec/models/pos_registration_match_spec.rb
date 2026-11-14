require "rails_helper"

RSpec.describe PosRegistrationMatch, type: :model do
  describe "answer!" do
    let(:match) { FactoryBot.create(:pos_registration_match) }
    let(:user) { match.bike.user }

    it "confirms for the owner and queues the merge" do
      expect(match.answer!(user: FactoryBot.create(:user_confirmed), merge: true)).to be_falsey
      expect(match.reload.status).to eq "pending"

      expect(match.answer!(user:, merge: true)).to be_truthy
      expect(match.reload.status).to eq "confirmed"
      expect(BikeJobs::MergePosRegistrationJob.jobs.map { it["args"] }).to eq([[match.id]])
      # Already answered
      expect(match.answer!(user:, merge: false)).to be_falsey
    end

    it "declines" do
      expect(match.answer!(user:, merge: false)).to be_truthy
      expect(match.reload.status).to eq "declined"
      expect(BikeJobs::MergePosRegistrationJob.jobs).to be_empty
    end

    it "doesn't take an answer on a review candidate" do
      match.update!(review_reasons: ["multiple_registrations"])
      expect(match.answer!(user:, merge: true)).to be_falsey
      expect(match.reload.status).to eq "pending"
    end
  end

  describe "bike and pos_bike" do
    let(:match) { FactoryBot.create(:pos_registration_match, status: :merged) }

    it "includes deleted and hidden registrations, preloaded too" do
      match.pos_bike.update!(marked_user_hidden: true)
      match.bike.destroy!
      expect(described_class.includes(:bike, :pos_bike).find(match.id)).to have_attributes(bike: match.bike, pos_bike: match.pos_bike)
    end
  end

  describe "merged_into" do
    let(:match) { FactoryBot.create(:pos_registration_match, status: :merged) }

    it "is the POS registration, once the owner's is deleted" do
      expect(described_class.merged_into(match.bike)).to be_nil
      match.bike.destroy!
      expect(described_class.merged_into(Bike.unscoped.find(match.bike_id))).to eq match.pos_bike
    end
  end
end
