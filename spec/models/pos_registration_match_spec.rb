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

  context "the shop registered it to another email" do
    let(:match) { FactoryBot.create(:pos_registration_match, :different_email) }
    let(:user) { match.bike.user }

    it "is asked there, and only its token answers" do
      expect(match).to have_attributes(different_email?: true, asked_email: "shop-customer@example.com", asked_user: nil)
      expect(match.answer!(user:, merge: true)).to be_falsey
      expect(match.answer!(token: "wrong", merge: true)).to be_falsey
      expect(match.reload.status).to eq "pending"

      expect(match.answer!(token: match.token, merge: true)).to be_truthy
      expect(match.reload).to have_attributes(status: "confirmed", merger_id: nil)
      expect(BikeJobs::MergePosRegistrationJob.jobs.map { it["args"] }).to eq([[match.id]])
    end

    it "isn't mergeable once another account claims the POS registration" do
      expect(match.mergeable?).to be_truthy
      match.pos_bike.current_ownership.update!(user: FactoryBot.create(:user_confirmed), claimed: true)
      expect(match.reload.mergeable?).to be_falsey
    end

    it "isn't mergeable once the POS registration is transferred, so the next owner isn't asked" do
      BikeServices::OwnershipTransferer.find_or_create(match.pos_bike, updator: match.pos_bike.creator,
        new_owner_email: "next-owner@example.com")
      expect(match.reload.mergeable?).to be_falsey
    end
  end

  describe "owners_pos_registration?" do
    let(:user) { FactoryBot.create(:user_confirmed, email: "john.smith@gmail.com") }
    let(:match) { FactoryBot.create(:pos_registration_match, user:, pos_owner_email:) }
    let(:pos_owner_email) { "JohnSmith+bikeshop@googlemail.com" }

    it "counts an address that delivers to one of the owner's emails, until another account claims it" do
      expect(match.pos_bike.user_id).to be_nil
      expect(described_class.owners_pos_registration?(match.bike, match.pos_bike)).to be_truthy
      expect(match.mergeable?).to be_truthy
      match.pos_bike.current_ownership.update!(user: FactoryBot.create(:user_confirmed), claimed: true)
      expect(described_class.owners_pos_registration?(match.bike, match.reload.pos_bike)).to be_falsey
    end

    context "another address" do
      let(:pos_owner_email) { "john.smith@example.com" }

      it "is false" do
        expect(described_class.owners_pos_registration?(match.bike, match.pos_bike)).to be_falsey
        expect(match.mergeable?).to be_falsey
      end
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

    it "includes registrations out of Bike.current, preloaded with Bike's default includes" do
      match.pos_bike.update!(marked_user_hidden: true)
      match.pos_bike.update_columns(example: true, likely_spam: true)
      match.bike.destroy!
      preloaded = described_class.includes(:bike, :pos_bike).find(match.id)
      expect(preloaded).to have_attributes(bike: match.bike, pos_bike: match.pos_bike)
      # The admin table reads these for each row
      [preloaded.bike, preloaded.pos_bike].each do |bike|
        expect(Bike.default_includes.includes_values.map { bike.association(it).loaded? }).to all(be true)
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
