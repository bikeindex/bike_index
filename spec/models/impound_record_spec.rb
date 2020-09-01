require "rails_helper"

RSpec.describe ImpoundRecord, type: :model do
  let!(:bike) { FactoryBot.create(:bike) }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
  let(:user) { FactoryBot.create(:organization_member, organization: organization) }

  describe "validations" do
    it "marks the bike impounded only once" do
      expect(Bike.impounded.pluck(:id)).to eq([])
      expect(organization.enabled?("impound_bikes")).to be_truthy
      organization.reload
      expect(organization.enabled?("impound_bikes")).to be_truthy
      expect(bike.impounded?).to be_falsey
      bike.impound_records.create(user: user, bike: bike, organization: organization)
      bike.reload
      expect(bike.impounded?).to be_truthy
      expect(bike.impound_records.count).to eq 1
      impound_record = bike.current_impound_record
      expect(impound_record.organization).to eq organization
      expect(impound_record.user).to eq user
      expect(impound_record.current?).to be_truthy
      expect(Bike.impounded.pluck(:id)).to eq([bike.id])
      expect(organization.impound_records.bikes.pluck(:id)).to eq([bike.id])
    end
    context "bike already impounded" do
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
      it "errors" do
        bike.reload
        expect(bike.impounded?).to be_truthy
        expect(bike.impound_records.count).to eq 1
        new_impound_record = FactoryBot.build(:impound_record, bike: bike)
        expect(new_impound_record.save).to be_falsey
        bike.reload
        expect(bike.impound_records.count).to eq 1
        expect(new_impound_record.errors.full_messages.join).to match(/already/)
        expect(bike.impounded?).to be_truthy
      end
    end
    context "impound_record_update" do
      let!(:location) { FactoryBot.create(:location, organization: organization) }
      let!(:impound_record) { FactoryBot.create(:impound_record, user: user, bike: bike, organization: organization) }
      let!(:user2) { FactoryBot.create(:organization_member, organization: organization) }
      let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, user: user2, kind: "retrieved_by_owner") }
      it "updates the record and the user" do
        ImpoundUpdateBikeWorker.new.perform(impound_record.id)
        bike.reload
        expect(bike.impounded?).to be_truthy
        expect(bike.status_impounded?).to be_truthy
        expect(impound_record.user).to eq user
        expect(impound_record.location).to be_blank
        # Doesn't include move update kind, because there is no location
        expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - ["move_location"])

        impound_record_update.save
        expect(impound_record_update.resolved?).to be_truthy
        impound_record.reload
        expect(impound_record.resolved?).to be_truthy
        expect(impound_record.resolved_at).to be_within(1).of Time.current
        expect(impound_record.user_id).to eq user2.id
      end
    end
  end

  describe "resolved factory" do
    let!(:impound_record) { FactoryBot.create(:impound_record_resolved, status: "removed_from_bike_index") }
    it "creates with resolved issue" do
      impound_record.reload
      expect(impound_record.status).to eq "removed_from_bike_index"
      expect(impound_record.impound_record_updates.count).to eq 1
      expect(impound_record.resolving_update.kind).to eq "removed_from_bike_index"
    end
  end

  describe "impound_location" do
    let!(:location) { FactoryBot.create(:location, organization: organization, impound_location: true, default_impound_location: true) }
    let!(:location2) { FactoryBot.create(:location, organization: organization, impound_location: true) }
    let!(:impound_record) { FactoryBot.create(:impound_record, user: user, bike: bike, organization: organization) }
    let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, location: location2) }
    it "sets the impound location by default" do
      organization.reload
      expect(organization.enabled?("impound_bikes_locations")).to be_truthy
      expect(organization.default_impound_location).to eq location
      expect(impound_record.location).to eq location
      impound_record_update.save
      impound_record.reload
      expect(impound_record.location).to eq location2
    end
  end

  describe "update_associations" do
    let(:impound_record) { FactoryBot.build(:impound_record) }
    it "enqueues for create and update, not destroy" do
      expect {
        impound_record.save
      }.to change(ImpoundUpdateBikeWorker.jobs, :count).by 1
      expect{
        impound_record.update(updated_at: Time.current)
      }.to change(ImpoundUpdateBikeWorker.jobs, :count).by 1
      expect {
        impound_record.destroy
      }.to_not change(ImpoundUpdateBikeWorker.jobs, :count)
    end
  end
end
