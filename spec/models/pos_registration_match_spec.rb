require "rails_helper"

RSpec.describe PosRegistrationMatch, type: :model do
  describe "answer!" do
    let(:match) { FactoryBot.create(:pos_registration_match) }
    let(:user) { match.bike.user }

    it "confirms for the owner and queues the merge" do
      expect(match.answer!(user: FactoryBot.create(:user_confirmed), merge: true)).to be_falsey
      expect(match.reload.status).to eq "pending"

      expect(match.answer!(user:, merge: true)).to be_truthy
      expect(match.reload).to have_attributes(status: "confirmed", merger_id: user.id)
      expect(BikeJobs::MergePosRegistrationJob.jobs.map { it["args"] }).to eq([[match.id]])
      # Already answered
      expect(match.answer!(user:, merge: false)).to be_falsey
    end

    it "only takes true or false" do
      expect(match.answer!(user:, merge: "merge")).to be_falsey
      expect(match.answer!(user:, merge: nil)).to be_falsey
      expect(match.reload.status).to eq "pending"
    end

    it "declines" do
      expect(match.answer!(user:, merge: false)).to be_truthy
      expect(match.reload).to have_attributes(status: "declined", merger_id: nil)
      expect(BikeJobs::MergePosRegistrationJob.jobs).to be_empty
    end

    it "doesn't take an answer on a review candidate" do
      match.update!(review_reasons: ["multiple_registrations"])
      expect(match.answer!(user:, merge: true)).to be_falsey
      expect(match.reload.status).to eq "pending"
    end
  end

  describe "review_reasons_for" do
    let(:match) { FactoryBot.create(:pos_registration_match) }
    let(:reasons) { described_class.review_reasons_for(match.bike, match.pos_bike) }

    it "is empty for a clean pair" do
      expect(reasons).to eq []
    end

    it "checks the POS registration's serial for stolen history too" do
      match.pos_bike.update!(serial_number: "WTU999C9999")
      FactoryBot.create(:stolen_bike, serial_number: "WTU999C9999")
      expect(reasons).to eq ["stolen_history"]
    end

    it "includes bike versions" do
      FactoryBot.create(:bike_version, bike: match.pos_bike)
      expect(reasons).to eq ["bike_versions"]
    end
  end

  describe "bike and pos_bike" do
    let(:match) { FactoryBot.create(:pos_registration_match, status: :merged) }

    it "includes deleted and hidden registrations, preloaded with Bike's default includes" do
      match.pos_bike.update!(marked_user_hidden: true)
      match.bike.destroy!
      preloaded = described_class.includes(:bike, :pos_bike).find(match.id)
      expect(preloaded).to have_attributes(bike: match.bike, pos_bike: match.pos_bike)
      # The admin table reads these for each row
      [preloaded.bike, preloaded.pos_bike].each do |bike|
        expect(%i[primary_frame_color current_stolen_record current_ownership].map { bike.association(it).loaded? }).to all(be true)
      end
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
