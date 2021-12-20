require "rails_helper"

RSpec.describe MigrateCreationStateToOwnershipWorker, type: :job do
  let(:subject) { described_class.new }
  let(:before_migrate_time) { Time.at(1640030537) }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "migrate?" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike, creator: ownership.creator) }
    it "is falsey" do
      creation_state.reload
      ownership.reload
      expect(ownership.updated_at.to_i).to be > MigrateCreationStateToOwnershipWorker::END_TIMESTAMP
      expect(described_class.migrate?(ownership, creation_state)).to be_falsey
    end
    context "before time" do
      it "is truthy" do
        creation_state.update_column :updated_at, before_migrate_time
        ownership.update_column :updated_at, before_migrate_time
        creation_state.reload
        ownership.reload
        expect(described_class.migrate?(ownership, creation_state)).to be_truthy
      end
    end
  end

  describe "perform" do
    before do
      # Update the updated_at to be older
      creation_state.update_column :updated_at, before_migrate_time
      ownership.update_column :updated_at, before_migrate_time
      ownership.reload
      creation_state.reload
    end
    context "ascend pos" do
      let(:bike) { FactoryBot.create(:bike_ascend_pos, :with_ownership) }
      let!(:ownership) { bike.current_ownership }
      let!(:creation_state) { bike.current_creation_state }
      it "sets all the things" do
        expect(ownership.registration_info).to eq({})
        expect(bike.soon_current_ownership_id).to be_blank
        expect(described_class.migrate?(ownership, creation_state)).to be_truthy
        expect(creation_state.bulk_import_id).to be_present
        expect(creation_state.organization_id).to be_present
        expect(creation_state.status).to eq "status_with_owner"
        expect(creation_state.pos_kind).to eq "ascend_pos"
        expect(creation_state.origin_enum).to eq "bulk_import_worker"

        subject.perform(creation_state.id)
        ownership.reload
        creation_state.reload
        expect(ownership.pos_kind).to eq "ascend_pos"
        expect(ownership.origin).to eq "bulk_import_worker"
        expect(ownership.status).to eq "status_with_owner"
        # Extra check to make sure not nil
        expect(ownership.bulk_import_id).to eq creation_state.bulk_import.id
        expect(ownership.organization_id).to eq creation_state.organization.id
        expect(ownership.registration_info).to eq({})
        expect(described_class.migrate?(ownership, creation_state)).to be_falsey
      end
    end
    context "lightspeed pos" do
      let(:bike) { FactoryBot.create(:bike_lightspeed_pos, :with_ownership, creation_state_origin: "web") }
      let!(:ownership) { bike.current_ownership }
      let!(:creation_state) { bike.current_creation_state }
      it "sets all the things" do
        expect(ownership.registration_info).to eq({})
        expect(bike.soon_current_ownership_id).to be_blank
        expect(described_class.migrate?(ownership, creation_state)).to be_truthy
        expect(creation_state.bulk_import_id).to be_blank
        expect(creation_state.organization_id).to be_present
        expect(creation_state.status).to eq "status_with_owner"
        expect(creation_state.pos_kind).to eq "lightspeed_pos"
        # NOTE: There are some lightspeed that are web - this is a bug and shouldn't have happened, correcting here
        expect(creation_state.origin_enum).to eq "web"

        subject.perform(creation_state.id)
        ownership.reload
        creation_state.reload
        expect(ownership.pos_kind).to eq "lightspeed_pos"
        expect(ownership.origin).to eq "api_v1"
        expect(ownership.status).to eq "status_with_owner"
        # Extra check to make sure not nil
        expect(ownership.organization_id).to eq creation_state.organization.id
        expect(ownership.registration_info).to eq({})
        expect(described_class.migrate?(ownership, creation_state)).to be_falsey
      end
    end
    context "registration_info" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership) }
      let!(:ownership) { bike.current_ownership }
      let(:registration_info) { {zipcode: "99999", country: "US", city: "New City", street: "main main street"} }
      let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike, registration_info: registration_info) }
      it "includes the registration_info" do
        expect(described_class.migrate?(ownership, creation_state)).to be_truthy
        expect(bike.reload.registration_info).to eq registration_info.as_json
        expect(ownership.registration_info).to eq({})

        subject.perform(creation_state.id)
        ownership.reload
        creation_state.reload
        expect(ownership.registration_info).to eq registration_info.as_json
        expect(described_class.migrate?(ownership, creation_state)).to be_falsey
      end
    end
  end
end
