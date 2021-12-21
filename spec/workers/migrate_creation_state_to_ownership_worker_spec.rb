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
      expect(described_class.migrate?(creation_state, ownership)).to be_falsey
    end
    context "before time" do
      it "is truthy" do
        creation_state.update_column :updated_at, before_migrate_time
        ownership.update_column :created_at, before_migrate_time
        creation_state.reload
        ownership.reload
        expect(described_class.migrate?(creation_state, ownership)).to be_truthy
      end
    end
  end

  describe "perform" do
    before do
      # Update the updated_at to be older
      creation_state.update_column :updated_at, before_migrate_time
      ownership.update_column :created_at, before_migrate_time
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
        expect(described_class.migrate?(creation_state, ownership)).to be_truthy
        expect(creation_state.bulk_import_id).to be_present
        expect(creation_state.organization_id).to be_present
        expect(creation_state.status).to eq "status_with_owner"
        expect(creation_state.pos_kind).to eq "ascend_pos"
        expect(creation_state.origin_enum).to eq "bulk_import_worker"

        Sidekiq::Worker.clear_all
        subject.perform(creation_state.id)
        expect(AfterBikeSaveWorker.jobs.count).to eq 0
        ownership.reload
        creation_state.reload
        expect(creation_state.ownership_id).to eq ownership.id
        expect(ownership.pos_kind).to eq "ascend_pos"
        expect(ownership.origin).to eq "bulk_import_worker"
        expect(ownership.status).to eq "status_with_owner"
        expect(ownership.is_new).to be_truthy
        # Extra check to make sure not nil
        expect(ownership.bulk_import_id).to eq creation_state.bulk_import.id
        expect(ownership.organization_id).to eq creation_state.organization.id
        expect(ownership.registration_info).to eq({})
        expect(described_class.migrate?(creation_state, ownership)).to be_falsey
      end
    end
    context "lightspeed pos" do
      let(:bike) { FactoryBot.create(:bike_lightspeed_pos, :with_ownership, creation_state_origin: "web") }
      let!(:ownership) { bike.current_ownership }
      let!(:creation_state) { bike.current_creation_state }
      it "sets all the things" do
        expect(ownership.registration_info).to eq({})
        expect(bike.soon_current_ownership_id).to be_blank
        expect(described_class.migrate?(creation_state, ownership)).to be_truthy
        expect(creation_state.bulk_import_id).to be_blank
        expect(creation_state.organization_id).to be_present
        expect(creation_state.status).to eq "status_with_owner"
        expect(creation_state.pos_kind).to eq "lightspeed_pos"
        # NOTE: There are some lightspeed that are web - this is a bug and shouldn't have happened, correcting here
        expect(creation_state.origin_enum).to eq "web"

        subject.perform(creation_state.id)
        ownership.reload
        creation_state.reload
        expect(creation_state.ownership_id).to eq ownership.id
        expect(ownership.pos_kind).to eq "lightspeed_pos"
        expect(ownership.origin).to eq "api_v1"
        expect(ownership.status).to eq "status_with_owner"
        expect(ownership.is_new).to be_truthy
        # Extra check to make sure not nil
        expect(ownership.organization_id).to eq creation_state.organization.id
        expect(ownership.registration_info).to eq({})
        expect(described_class.migrate?(creation_state, ownership)).to be_falsey
      end
    end
    context "registration_info" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership) }
      let!(:ownership) { bike.current_ownership }
      let(:registration_info) { {zipcode: "99999", country: "US", city: "New City", street: "main main street"} }
      let!(:creation_state) { FactoryBot.create(:creation_state, bike: bike, registration_info: registration_info) }
      it "includes the registration_info" do
        expect(described_class.migrate?(creation_state, ownership)).to be_truthy
        expect(bike.reload.registration_info).to eq registration_info.as_json
        expect(ownership.registration_info).to eq({})

        subject.perform(creation_state.id)
        ownership.reload
        creation_state.reload
        expect(creation_state.ownership_id).to eq ownership.id
        expect(ownership.is_new).to be_falsey
        expect(ownership.registration_info).to eq registration_info.as_json
        expect(described_class.migrate?(creation_state, ownership)).to be_falsey
      end
      context "with multiple ownerships" do
        let(:ownership2) { FactoryBot.create(:ownership, bike: bike, creator: ownership.creator) }
        it "only updates the first ownership" do
          ownership2.reload
          ownership2.update_column :created_at, before_migrate_time
          expect(ownership2.reload.current?).to be_truthy
          expect(ownership2.registration_info).to eq({})
          expect(ownership.reload.current?).to be_falsey

          expect(described_class.migrate?(creation_state, ownership)).to be_truthy
          expect(described_class.migrate?(creation_state, ownership2)).to be_truthy
          expect(bike.reload.registration_info).to eq registration_info.as_json
          expect(ownership.registration_info).to eq({})

          subject.perform(creation_state.id)
          ownership.reload
          creation_state.reload
          expect(creation_state.ownership_id).to eq ownership.id
          expect(ownership.registration_info).to eq registration_info.as_json
          expect(described_class.migrate?(creation_state, ownership)).to be_falsey
          expect(described_class.migrate?(creation_state, ownership2)).to be_falsey
        end
      end
      context "with multiple of the same creation_state" do
        let!(:creation_state2) { FactoryBot.create(:creation_state, bike: bike, registration_info: registration_info, creator: creation_state.creator) }
        it "deletes the extra" do
          creation_state2.reload
          creation_state2.update_column :updated_at, before_migrate_time
          expect(CreationState.where(id: creation_state2.id).count).to eq 1
          expect(described_class.migrate?(creation_state, ownership)).to be_truthy
          expect(described_class.migrate?(creation_state2, ownership)).to be_truthy
          expect(bike.reload.registration_info).to eq registration_info.as_json
          expect(bike.current_creation_state&.id).to eq creation_state.id
          expect(ownership.registration_info).to eq({})

          subject.perform(creation_state.id)
          ownership.reload
          creation_state.reload
          expect(CreationState.where(id: creation_state2.id).count).to eq 0
          expect(creation_state.ownership_id).to eq ownership.id
          expect(ownership.registration_info).to eq registration_info.as_json
          expect(described_class.migrate?(creation_state, ownership)).to be_falsey
          expect(creation_state.registration_info["deleted_creation_states"]).to eq([creation_state2.id])
        end
      end
      context "with different creation states" do
        let!(:creation_state2) { FactoryBot.create(:creation_state, bike: bike) }
        it "errors for the second" do
          creation_state2.reload
          creation_state2.update_column :updated_at, before_migrate_time
          expect(CreationState.where(id: creation_state2.id).count).to eq 1
          expect(described_class.migrate?(creation_state, ownership)).to be_truthy
          expect(described_class.migrate?(creation_state2, ownership)).to be_truthy
          expect(ownership.registration_info).to eq({})

          subject.perform(creation_state.id)
          ownership.reload
          creation_state.reload
          expect(creation_state.ownership_id).to eq ownership.id
          expect(ownership.registration_info).to eq registration_info.as_json
          expect(described_class.migrate?(creation_state, ownership)).to be_falsey
          expect(creation_state.registration_info["deleted_creation_states"]).to be_blank

          ownership_updated_at = ownership.updated_at
          subject.perform(creation_state2.id)
          # It shouldn't have updated the ownership!
          expect(ownership.reload.updated_at).to eq ownership_updated_at
          expect(MigrateCreationStateToOwnershipWorker.creation_states_with_earlier.pluck(:id)).to eq([creation_state2.id])
        end
      end
    end
  end
end
