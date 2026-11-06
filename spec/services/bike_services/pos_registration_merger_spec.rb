require "rails_helper"

RSpec.describe BikeServices::PosRegistrationMerger do
  let(:match) { FactoryBot.create(:pos_registration_match) }
  let(:bike) { match.bike }
  let(:pos_bike) { match.pos_bike }

  it "keeps the POS registration, with what the owner added, and deletes theirs" do
    bike.update!(frame_model: "Roadster", year: 2024, description: "Red basket")
    pos_bike.update!(year: 2023)
    public_image = FactoryBot.create(:public_image, imageable: bike)
    component = FactoryBot.create(:component, bike:)
    bike_sticker = FactoryBot.create(:bike_sticker_claimed, bike:, user: bike.user)
    expect(pos_bike.current_ownership.claimed?).to be_falsey

    expect(described_class.merge(match)).to be_truthy
    expect(pos_bike.reload).to have_attributes(frame_model: "Roadster", year: 2023, description: "Red basket")
    expect(public_image.reload.imageable).to eq pos_bike
    expect(component.reload.bike_id).to eq pos_bike.id
    expect(bike_sticker.reload.bike_id).to eq pos_bike.id
    expect(pos_bike.current_ownership.reload.claimed?).to be_truthy
    expect(match.reload.status).to eq "merged"
    expect(Bike.unscoped.find(bike.id).deleted_at).to be_present
    expect(CallbackJobs::AfterBikeSaveJob.jobs.map { it["args"] }).to include([bike.id], [pos_bike.id])
  end

  it "records a theft since the match and doesn't merge" do
    FactoryBot.create(:stolen_bike, serial_number: bike.serial_number)
    expect(described_class.merge(match)).to be_falsey
    expect(match.reload).to have_attributes(status: "pending", review_reasons: ["stolen_history"])
    expect(bike.reload.deleted_at).to be_blank
  end

  it "records an impound since the match and doesn't merge" do
    FactoryBot.create(:impound_record, bike: pos_bike)
    expect(described_class.merge(match)).to be_falsey
    expect(match.reload.review_reasons).to eq ["impounded"]
  end

  it "doesn't merge once the POS registration is someone else's" do
    BikeServices::OwnershipTransferer.find_or_create(pos_bike, updator: bike.user, new_owner_email: "new-owner@example.com")
    expect(described_class.merge(match)).to be_falsey
    expect(bike.reload.deleted_at).to be_blank
  end

  it "doesn't merge a review candidate or a declined match" do
    match.update!(review_reasons: ["multiple_registrations"])
    expect(described_class.merge(match)).to be_falsey
    match.update!(review_reasons: [], status: :declined)
    expect(described_class.merge(match)).to be_falsey
    expect(bike.reload.deleted_at).to be_blank
  end
end
