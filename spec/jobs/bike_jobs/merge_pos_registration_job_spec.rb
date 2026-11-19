require "rails_helper"

RSpec.describe BikeJobs::MergePosRegistrationJob, type: :job do
  let(:instance) { described_class.new }
  let(:match) { FactoryBot.create(:pos_registration_match, status: :confirmed) }
  let(:bike) { match.bike }
  let(:pos_bike) { match.pos_bike }
  let(:user) { bike.user }

  # Written because UserJobs::MergeAdditionalEmailJob left impound updates and claims on the old user (#4777)
  it "moves or lists every column that can point at a bike" do
    bike_id_columns = ActiveRecord::Base.connection.select_rows("SELECT table_name, column_name FROM information_schema.columns " \
      "WHERE column_name LIKE '%bike_id' AND table_schema = 'public'").map { it.join(".") }
    # Associations to Bike named something else, e.g. impound_claims.bike_claimed_id, and polymorphic ones
    Rails.application.eager_load!
    association_columns = ApplicationRecord.descendants.reject(&:abstract_class?).flat_map do |model|
      model.reflect_on_all_associations(:belongs_to).select { it.polymorphic? || it.class_name == "Bike" }
        .map { "#{model.table_name}.#{it.foreign_key}" }
    end
    expect((bike_id_columns + association_columns).uniq).to match_array(described_class::MOVED_MODELS.map { "#{it.table_name}.bike_id" } +
      described_class::MERGED_COLUMNS + described_class::LEFT_COLUMNS.keys)
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
    # What the owner entered wins
    expect(pos_bike.reload).to have_attributes(frame_model: "Roadster", year: 2024, description: "Red basket",
      propulsion_type: "pedal-assist", user_hidden: false)
    expect([public_image, private_image].map { PublicImage.unscoped.find(it.id).imageable_id }).to eq([pos_bike.id] * 2)
    expect([component, bike_sticker, bike_organization, customer_contact, notification].map { it.reload.bike_id })
      .to eq([pos_bike.id] * 5)
    expect(pos_bike.current_ownership.reload).to have_attributes(claimed: true, registration_info: {"phone" => "7183839292"})
    expect(match.reload).to have_attributes(status: "merged", merged_at: be_within(1.minute).of(Time.current))
    expect(Bike.unscoped.find(bike.id).deleted_at).to be_present
    expect(CallbackJobs::AfterBikeSaveJob.jobs.map { it["args"] }).to include([bike.id], [pos_bike.id])
    expect(PosRegistrationMatch.merged_into(Bike.unscoped.find(bike.id))).to eq pos_bike
  end

  it "takes the owner's defaults and blanks too, and keeps the shop's organization permission and note" do
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
    strava_integration = FactoryBot.create(:strava_integration, user:)
    strava_gear = FactoryBot.create(:strava_gear, item: bike, strava_integration:)

    instance.perform(match.id)
    expect(pos_bike.reload).to have_attributes(propulsion_type: "foot-pedal", description: "", frame_size: "m",
      frame_size_number: nil, frame_size_unit: "ordinal")
    expect(pos_bike.bike_organizations.find_by(organization:).can_not_edit_claimed).to be_truthy
    expect([pos_bike_note, bike_note, other_note].map { it.reload.bike_id }).to eq([pos_bike.id, bike.id, pos_bike.id])
    expect(pos_bike.current_ownership.address_record_id).to eq address_record.id
    expect(strava_gear.reload.item_id).to eq pos_bike.id
  end

  # Sidekiq retries it, then it's dead and in Honeybadger
  it "raises, leaving nothing half-merged, when the merge fails" do
    component = FactoryBot.create(:component, bike:)
    allow_any_instance_of(Bike).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
    expect { instance.perform(match.id) }.to raise_error(ActiveRecord::RecordNotDestroyed)
    expect(component.reload.bike_id).to eq bike.id
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: [], merged_at: nil)
    expect(bike.reload.deleted_at).to be_blank
    expect(CallbackJobs::AfterBikeSaveJob.jobs).to be_empty
  end

  # Written because re-claiming a sticker of the POS registration's organization failed the merge on every retry
  it "moves the shop's sticker without re-claiming it, and the owner's submission and impound claim" do
    organization = pos_bike.bike_organizations.first.organization
    sticker_claimer = FactoryBot.create(:user)
    bike_sticker = FactoryBot.create(:bike_sticker_claimed, bike:, user: sticker_claimer, organization:)
    claimed_at = bike_sticker.reload.claimed_at
    b_param = FactoryBot.create(:b_param, created_bike_id: bike.id)
    impound_claim = FactoryBot.create(:impound_claim)
    impound_claim.update_column(:bike_submitting_id, bike.id)
    user_alert = FactoryBot.create(:user_alert, kind: "unassigned_bike_org", user:, bike:,
      organization: FactoryBot.create(:organization))

    instance.perform(match.id)
    expect(match.reload.status).to eq "merged"
    expect(bike_sticker.reload).to have_attributes(bike_id: pos_bike.id, previous_bike_id: bike.id,
      user_id: sticker_claimer.id, claimed_at:)
    expect(bike_sticker.bike_sticker_updates.order(:id).last).to have_attributes(bike_id: pos_bike.id, user_id: nil, kind: "re_claim")
    expect(b_param.reload.created_bike_id).to eq pos_bike.id
    expect(impound_claim.reload.bike_submitting_id).to eq pos_bike.id
    expect(user_alert.reload.resolved?).to be_truthy
  end

  it "doesn't merge once there's another registration of the POS registration, and records why" do
    other_match = FactoryBot.create(:pos_registration_match, pos_bike:,
      bike: FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer: bike.manufacturer, serial_number: bike.serial_number))
    expect(other_match.reload.review_reasons).to eq []
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["multiple_registrations"])
    expect(bike.reload.deleted_at).to be_blank
  end

  it "doesn't merge once a merged registration of the POS registration came first" do
    other_bike = FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer: bike.manufacturer, serial_number: bike.serial_number)
    FactoryBot.create(:pos_registration_match, pos_bike:, bike: other_bike, status: :merged)
    other_bike.destroy!
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["multiple_registrations"])
  end

  it "doesn't merge while their registration is mid-transfer" do
    ownership = bike.current_ownership
    FactoryBot.create(:ownership, bike:, creator: user, owner_email: "new-owner@example.com")
    # The new ownership is committed, but its after_commit hasn't pointed the bike at it yet
    ownership.update_column(:current, true)
    bike.update_column(:current_ownership_id, ownership.id)
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["changed_since_confirmed"])
    expect(bike.reload.deleted_at).to be_blank
  end

  it "points a moved graduated notification at the kept bike's organization" do
    organization = FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"],
      graduated_notification_interval: 1.year)
    pos_bike_organization = FactoryBot.create(:bike_organization, bike: pos_bike, organization:)
    bike_organization = FactoryBot.create(:bike_organization, bike:, organization:)
    graduated_notification = FactoryBot.create(:graduated_notification, bike:, organization:)
    expect(graduated_notification.reload.bike_organization_id).to eq bike_organization.id

    instance.perform(match.id)
    expect(match.reload.status).to eq "merged"
    expect(graduated_notification.reload).to have_attributes(bike_id: pos_bike.id, bike_organization_id: pos_bike_organization.id)
  end

  it "moves a graduated membership, so its renewal link restores the kept bike's" do
    organization = FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"],
      graduated_notification_interval: 1.year)
    bike_organization = FactoryBot.create(:bike_organization, bike:, organization:)
    graduated_notification = FactoryBot.create(:graduated_notification, bike:, organization:)
    bike_organization.destroy!
    expect(graduated_notification.reload.bike_organization_id).to eq bike_organization.id

    instance.perform(match.id)
    expect(match.reload.status).to eq "merged"
    expect(BikeOrganization.unscoped.find(bike_organization.id).bike_id).to eq pos_bike.id
    expect(graduated_notification.reload.bike_id).to eq pos_bike.id
  end

  it "keeps the owner's more restrictive permission on a graduated membership" do
    organization = FactoryBot.create(:organization)
    pos_bike_organization = FactoryBot.create(:bike_organization, bike: pos_bike, organization:)
    bike_organization = FactoryBot.create(:bike_organization, bike:, organization:, can_not_edit_claimed: true)
    [pos_bike_organization, bike_organization].each(&:destroy!)

    instance.perform(match.id)
    expect(match.reload.status).to eq "merged"
    expect(BikeOrganization.unscoped.find(pos_bike_organization.id).can_not_edit_claimed).to be_truthy
  end

  it "doesn't merge once the POS registration is really deleted" do
    BikeJobs::BikeDeleterJob.new.perform(pos_bike.id, true)
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["changed_since_confirmed"])
    expect(bike.reload.deleted_at).to be_blank
  end

  it "records a theft since the answer and leaves it confirmed" do
    FactoryBot.create(:stolen_bike, serial_number: bike.serial_number)
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
    expect(bike.reload.deleted_at).to be_blank
    expect(CallbackJobs::AfterBikeSaveJob.jobs).to be_empty
  end

  it "leaves another athlete's Strava gear" do
    strava_gear = FactoryBot.create(:strava_gear, item: bike)
    instance.perform(match.id)
    expect(match.reload.status).to eq "merged"
    expect(strava_gear.reload.item_id).to eq bike.id
  end

  # Written because a stolen serial edited onto the POS registration slipped past the veto
  it "doesn't merge once a serial was edited, and records why" do
    pos_bike.update!(serial_number: "OTHER98765")
    FactoryBot.create(:stolen_bike, serial_number: "OTHER98765")
    instance.perform(match.id)
    expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["changed_since_confirmed"])
    expect(match.merging?).to be_falsey
    expect(bike.reload.deleted_at).to be_blank
  end

  it "doesn't merge once the POS registration is someone else's, or an unconfirmed match" do
    BikeServices::OwnershipTransferer.find_or_create(pos_bike, updator: user, new_owner_email: "new-owner@example.com")
    instance.perform(match.id)
    expect(match.reload.review_reasons).to eq ["changed_since_confirmed"]
    expect(bike.reload.deleted_at).to be_blank

    pending_match = FactoryBot.create(:pos_registration_match)
    instance.perform(pending_match.id)
    expect(pending_match.reload.status).to eq "pending"
    expect(pending_match.bike.reload.deleted_at).to be_blank
  end
end
