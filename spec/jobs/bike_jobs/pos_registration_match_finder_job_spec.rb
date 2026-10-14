require "rails_helper"

RSpec.describe BikeJobs::PosRegistrationMatchFinderJob, type: :job do
  let(:instance) { described_class.new }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:serial_number) { "WTU123C4567" }
  let(:creation_state_origin) { "web" }
  let(:creation_pos_kind) { "" }
  let(:creation_organization) { nil }
  let(:bike) do
    FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer:, serial_number:, creation_state_origin:,
      creation_pos_kind:, creation_organization:, claimed_at: Time.current)
  end
  let(:pos_bike_factory) { :bike_lightspeed_pos }
  let(:pos_owner_email) { user.email }
  let(:pos_created_at) { Time.current - 30.days }
  let!(:pos_bike) do
    FactoryBot.create(pos_bike_factory, owner_email: pos_owner_email, manufacturer:, serial_number:, created_at: pos_created_at)
  end

  it "records a pending match once" do
    expect(pos_bike.current_ownership.user_id).to eq user.id
    expect {
      instance.perform(bike.id)
      instance.perform(bike.id)
    }.to change(PosRegistrationMatch, :count).by 1
    expect(PosRegistrationMatch.last).to have_attributes(bike_id: bike.id, pos_bike_id: pos_bike.id, user_id: user.id, status: "pending")
  end

  context "ascend pos bike registered from the app" do
    let(:pos_bike_factory) { :bike_ascend_pos }
    let(:creation_state_origin) { "api_v3" }

    it "records a match" do
      instance.perform(bike.id)
      expect(PosRegistrationMatch.pluck(:bike_id, :pos_bike_id)).to eq([[bike.id, pos_bike.id]])
    end
  end

  shared_examples "records no match" do
    it "doesn't record a match" do
      instance.perform(bike.id)
      expect(PosRegistrationMatch.count).to eq 0
    end
  end

  context "another manufacturer's bike with the serial is stolen" do
    before { FactoryBot.create(:stolen_bike, serial_number:) }

    include_examples "records no match"
  end

  context "registered from a sticker" do
    let(:creation_state_origin) { "sticker" }

    it "records a match" do
      instance.perform(bike.id)
      expect(PosRegistrationMatch.pluck(:bike_id, :pos_bike_id)).to eq([[bike.id, pos_bike.id]])
    end
  end

  context "a bike with the serial only has stolen status" do
    before { FactoryBot.create(:bike, serial_number:).update_column(:status, "status_stolen") }

    include_examples "records no match"
  end

  context "a bike with the serial only has a current stolen record id" do
    before do
      FactoryBot.create(:bike, serial_number:).update_column(:current_stolen_record_id, FactoryBot.create(:stolen_record).id)
    end

    include_examples "records no match"
  end

  context "another manufacturer's example bike with the serial is stolen" do
    before { FactoryBot.create(:stolen_bike, serial_number:, example: true) }

    include_examples "records no match"
  end

  context "a deleted bike with the serial was stolen and recovered" do
    before do
      deleted_bike = FactoryBot.create(:bike, serial_number:)
      FactoryBot.create(:stolen_record_recovered, bike: deleted_bike)
      deleted_bike.destroy
      expect(deleted_bike.reload).to have_attributes(status: "status_with_owner", current_stolen_record_id: nil, deleted_at: be_present)
    end

    include_examples "records no match"
  end

  context "pos bike owned by someone else" do
    let(:pos_owner_email) { "shop-customer@example.com" }

    include_examples "records no match"
  end

  context "new bike registered by an organization" do
    let(:creation_organization) { FactoryBot.create(:organization) }

    include_examples "records no match"
  end

  context "new bike registered through a POS" do
    let(:creation_pos_kind) { "lightspeed_pos" }

    include_examples "records no match"
  end

  context "new bike from a non-customer origin" do
    let(:creation_state_origin) { "bulk_import_worker" }

    include_examples "records no match"
  end

  context "earlier bike not registered through a POS" do
    let(:pos_bike_factory) { :bike_organized }

    include_examples "records no match"
  end

  context "earlier bike registered more than 365 days before" do
    let(:pos_created_at) { Time.current - 366.days }

    include_examples "records no match"
  end

  context "serial shorter than 6 characters" do
    let(:serial_number) { "WTU12" }

    include_examples "records no match"
  end

  context "multiple earlier pos bikes" do
    before { FactoryBot.create(:bike_lightspeed_pos, owner_email: user.email, manufacturer:, serial_number:, created_at: pos_created_at) }

    include_examples "records no match"
  end

  context "pos bike transferred to the owner" do
    let(:pos_owner_email) { "shop-customer@example.com" }
    before do
      BikeServices::OwnershipTransferer.find_or_create(pos_bike, updator: pos_bike.creator, new_owner_email: user.email)
      expect(pos_bike.reload.current_ownership.user_id).to eq user.id
    end

    include_examples "records no match"
  end

  context "pos bike impounded" do
    before { FactoryBot.create(:impound_record, bike: pos_bike) }

    include_examples "records no match"
  end

  context "new bike with a marketplace listing" do
    before { FactoryBot.create(:marketplace_listing, item: bike) }

    include_examples "records no match"
  end
end
