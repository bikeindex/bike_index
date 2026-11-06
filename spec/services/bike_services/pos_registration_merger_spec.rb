require "rails_helper"

RSpec.describe BikeServices::PosRegistrationMerger do
  let(:match) { FactoryBot.create(:pos_registration_match) }
  let(:bike) { match.bike }
  let(:pos_bike) { match.pos_bike }
  let(:user) { bike.user }

  describe "confirm" do
    it "keeps the POS registration, with what the owner added, and deletes theirs" do
      bike.update!(frame_model: "Roadster", year: 2024, description: "Red basket", propulsion_type: "pedal-assist")
      pos_bike.update!(year: 2023, marked_user_hidden: true)
      public_image = FactoryBot.create(:public_image, imageable: bike)
      private_image = FactoryBot.create(:public_image, imageable: bike, is_private: true)
      component = FactoryBot.create(:component, bike:)
      bike_sticker = FactoryBot.create(:bike_sticker_claimed, bike:, user:)
      bike_organization = FactoryBot.create(:bike_organization, bike:)
      bike.current_ownership.update!(registration_info: {"phone" => "7183839292"})
      expect(pos_bike.reload.user_hidden).to be_truthy

      expect(described_class.confirm(match, user:)).to be_truthy
      # The owner's propulsion wins, the shop's year stays and its blank model is filled
      expect(pos_bike.reload).to have_attributes(frame_model: "Roadster", year: 2023, description: "Red basket",
        propulsion_type: "pedal-assist", user_hidden: false)
      expect([public_image, private_image].map { PublicImage.unscoped.find(it.id).imageable_id }).to eq([pos_bike.id] * 2)
      expect(component.reload.bike_id).to eq pos_bike.id
      expect(bike_sticker.reload.bike_id).to eq pos_bike.id
      expect(bike_organization.reload.bike_id).to eq pos_bike.id
      expect(pos_bike.current_ownership.reload).to have_attributes(claimed: true, registration_info: {"phone" => "7183839292"})
      expect(match.reload.status).to eq "merged"
      expect(Bike.unscoped.find(bike.id).deleted_at).to be_present
      expect(CallbackJobs::AfterBikeSaveJob.jobs.map { it["args"] }).to include([bike.id], [pos_bike.id, false, true])
    end

    it "records a theft since the match and leaves it confirmed" do
      FactoryBot.create(:stolen_bike, serial_number: bike.serial_number)
      expect(described_class.confirm(match, user:)).to be_falsey
      expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
      expect(bike.reload.deleted_at).to be_blank
    end

    it "records versions since the match and leaves it confirmed" do
      FactoryBot.create(:bike_version, bike:)
      expect(described_class.confirm(match, user:)).to be_falsey
      expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["bike_versions"])
    end

    # Written because a stolen serial edited onto the POS registration slipped past the veto
    it "doesn't merge once a serial was edited" do
      pos_bike.update!(serial_number: "OTHER98765")
      FactoryBot.create(:stolen_bike, serial_number: "OTHER98765")
      expect(described_class.confirm(match, user:)).to be_falsey
      expect(match.reload.status).to eq "pending"
      expect(bike.reload.deleted_at).to be_blank
    end

    it "doesn't merge for someone else, or once the POS registration is someone else's" do
      expect(described_class.confirm(match, user: FactoryBot.create(:user_confirmed))).to be_falsey
      BikeServices::OwnershipTransferer.find_or_create(pos_bike, updator: user, new_owner_email: "new-owner@example.com")
      expect(described_class.confirm(match, user:)).to be_falsey
      expect(match.reload.status).to eq "pending"
      expect(bike.reload.deleted_at).to be_blank
    end

    it "doesn't merge a review candidate or a declined match" do
      match.update!(review_reasons: ["multiple_registrations"])
      expect(described_class.confirm(match, user:)).to be_falsey
      match.update!(review_reasons: [], status: :declined)
      expect(described_class.confirm(match, user:)).to be_falsey
      expect(bike.reload.deleted_at).to be_blank
    end
  end

  describe "decline" do
    it "declines for the owner only" do
      described_class.decline(match, user: FactoryBot.create(:user_confirmed))
      expect(match.reload.status).to eq "pending"
      described_class.decline(match, user:)
      expect(match.reload.status).to eq "declined"
    end
  end
end
