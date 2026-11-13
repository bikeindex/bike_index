require "rails_helper"

RSpec.describe PosRegistrationMatch, type: :model do
  describe "answer!" do
    let(:match) { FactoryBot.create(:pos_registration_match) }
    let(:user) { match.bike.user }

    it "confirms for the owner and queues the merge" do
      expect(match.answer!(user: FactoryBot.create(:user_confirmed), same_bike: true)).to be_falsey
      expect(match.reload.status).to eq "pending"

      expect(match.answer!(user:, same_bike: true)).to be_truthy
      expect(match.reload.status).to eq "confirmed"
      expect(BikeJobs::MergePosRegistrationJob.jobs.map { it["args"] }).to eq([[match.id]])
      # Already answered
      expect(match.answer!(user:, same_bike: false)).to be_falsey
    end

    it "declines" do
      expect(match.answer!(user:, same_bike: false)).to be_truthy
      expect(match.reload.status).to eq "declined"
      expect(BikeJobs::MergePosRegistrationJob.jobs).to be_empty
    end

    it "records a theft since the email and doesn't queue the merge" do
      FactoryBot.create(:stolen_bike, serial_number: match.bike.serial_number)
      expect(match.answer!(user:, same_bike: true)).to be_truthy
      expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
      expect(BikeJobs::MergePosRegistrationJob.jobs).to be_empty
    end

    it "doesn't take an answer on a review candidate" do
      match.update!(review_reasons: ["multiple_registrations"])
      expect(match.answer!(user:, same_bike: true)).to be_falsey
      expect(match.reload.status).to eq "pending"
    end
  end

  describe "merged_into_id" do
    let(:match) { FactoryBot.create(:pos_registration_match, status: :merged) }

    it "is the POS registration, once the owner's is deleted" do
      expect(described_class.merged_into_id(match.bike)).to be_nil
      match.bike.destroy!
      expect(described_class.merged_into_id(Bike.unscoped.find(match.bike_id))).to eq match.pos_bike_id
    end
  end
end
