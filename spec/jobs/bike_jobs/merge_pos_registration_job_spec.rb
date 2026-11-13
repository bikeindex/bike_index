require "rails_helper"

RSpec.describe BikeJobs::MergePosRegistrationJob, type: :job do
  let(:instance) { described_class.new }
  let(:match) { FactoryBot.create(:pos_registration_match, status: :confirmed) }
  let(:bike) { match.bike }
  let(:pos_bike) { match.pos_bike }
  let(:user) { bike.user }

  # Written because UserJobs::MergeAdditionalEmailJob left impound updates and claims on the old user (#4777)
  it "moves or lists every table with a bike_id" do
    connection = ActiveRecord::Base.connection
    tables = connection.tables.select { connection.column_exists?(it, :bike_id) }
    expect(tables).to match_array(described_class::MOVED_MODELS.map(&:table_name) + described_class::MERGED_TABLES +
      described_class::LEFT_TABLES.keys)
  end

  it "keeps the POS registration, with what the owner added, and deletes theirs" do
    bike.update!(frame_model: "Roadster", year: 2024, description: "Red basket", propulsion_type: "pedal-assist")
    pos_bike.update!(year: 2023, marked_user_hidden: true)
    public_image = FactoryBot.create(:public_image, imageable: bike)
    private_image = FactoryBot.create(:public_image, imageable: bike, is_private: true)
    component = FactoryBot.create(:component, bike:)
    bike_sticker = FactoryBot.create(:bike_sticker_claimed, bike:, user:)
    bike_organization = FactoryBot.create(:bike_organization, bike:)
    customer_contact = FactoryBot.create(:customer_contact, bike:)
    notification = FactoryBot.create(:notification, user:, bike:, kind: :finished_registration)
    bike.current_ownership.update!(registration_info: {"phone" => "7183839292"})
    expect(pos_bike.reload.user_hidden).to be_truthy

    instance.perform(match.id)
    # The owner's propulsion wins, the shop's year stays and its blank model is filled
    expect(pos_bike.reload).to have_attributes(frame_model: "Roadster", year: 2023, description: "Red basket",
      propulsion_type: "pedal-assist", user_hidden: false)
    expect([public_image, private_image].map { PublicImage.unscoped.find(it.id).imageable_id }).to eq([pos_bike.id] * 2)
    expect([component, bike_sticker, bike_organization, customer_contact, notification].map { it.reload.bike_id })
      .to eq([pos_bike.id] * 5)
    expect(pos_bike.current_ownership.reload).to have_attributes(claimed: true, registration_info: {"phone" => "7183839292"})
    expect(match.reload.status).to eq "merged"
    expect(Bike.unscoped.find(bike.id).deleted_at).to be_present
    expect(CallbackJobs::AfterBikeSaveJob.jobs.map { it["args"] }).to include([bike.id], [pos_bike.id])
    expect(PosRegistrationMatch.merged_into_id(Bike.unscoped.find(bike.id))).to eq pos_bike.id
  end

  it "keeps the shop's values over the owner's defaults and blanks, and the shop's organization permission and note" do
    pos_bike.update!(propulsion_type: "pedal-assist", description: "Shop notes", frame_size: "56cm")
    bike.update_columns(description: "", frame_size: "m", frame_size_number: nil, frame_size_unit: "ordinal")
    expect(bike.reload.propulsion_type).to eq "foot-pedal"
    organization = pos_bike.bike_organizations.first.organization
    FactoryBot.create(:bike_organization, bike:, organization:, can_not_edit_claimed: true)
    pos_bike_note = FactoryBot.create(:bike_organization_note, bike: pos_bike, organization:)
    bike_note = FactoryBot.create(:bike_organization_note, bike:, organization:)
    other_note = FactoryBot.create(:bike_organization_note, bike:, organization: FactoryBot.create(:organization))
    address_record = FactoryBot.create(:address_record, kind: :ownership)
    bike.current_ownership.update!(address_record:)
    strava_gear = FactoryBot.create(:strava_gear, item: bike)

    instance.perform(match.id)
    # The owner's frame size replaces the shop's whole, not just its unit
    expect(pos_bike.reload).to have_attributes(propulsion_type: "pedal-assist", description: "Shop notes", frame_size: "m",
      frame_size_number: nil, frame_size_unit: "ordinal")
    expect(pos_bike.bike_organizations.find_by(organization:).can_not_edit_claimed).to be_truthy
    expect([pos_bike_note, bike_note, other_note].map { it.reload.bike_id }).to eq([pos_bike.id, bike.id, pos_bike.id])
    expect(pos_bike.current_ownership.address_record_id).to eq address_record.id
    expect(strava_gear.reload.item_id).to eq pos_bike.id
  end

  it "records a theft since the answer and leaves it confirmed" do
    FactoryBot.create(:stolen_bike, serial_number: bike.serial_number)
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
    expect(bike.reload.deleted_at).to be_blank
    expect(CallbackJobs::AfterBikeSaveJob.jobs).to be_empty
  end

  # Written because a stolen serial edited onto the POS registration slipped past the veto
  it "doesn't merge once a serial was edited" do
    pos_bike.update!(serial_number: "OTHER98765")
    FactoryBot.create(:stolen_bike, serial_number: "OTHER98765")
    instance.perform(match.id)
    expect(match.reload.status).to eq "confirmed"
    expect(bike.reload.deleted_at).to be_blank
  end

  it "doesn't merge once the POS registration is someone else's, or an unconfirmed match" do
    BikeServices::OwnershipTransferer.find_or_create(pos_bike, updator: user, new_owner_email: "new-owner@example.com")
    instance.perform(match.id)
    expect(bike.reload.deleted_at).to be_blank

    pending_match = FactoryBot.create(:pos_registration_match)
    instance.perform(pending_match.id)
    expect(pending_match.reload.status).to eq "pending"
    expect(pending_match.bike.reload.deleted_at).to be_blank
  end
end
