require "rails_helper"

RSpec.describe ImpoundRecord, type: :model do
  it_behaves_like "geocodeable"
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
      expect(impound_record.kind).to eq "impounded"
      expect(impound_record.impounded_at).to be_within(1).of impound_record.created_at
    end
    context "bike already impounded" do
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
      it "errors" do
        expect(impound_record.to_coordinates).to eq([nil, nil])
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
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, user: user, bike: bike, organization: organization) }
      let!(:user2) { FactoryBot.create(:organization_member, organization: organization) }
      let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, user: user2, kind: "retrieved_by_owner") }
      let(:valid_update_kinds) { ImpoundRecordUpdate.kinds - %w[move_location claim_approved claim_denied] }
      it "updates the record and the user" do
        ImpoundUpdateBikeWorker.new.perform(impound_record.id)
        bike.reload
        expect(bike.impounded?).to be_truthy
        expect(bike.status_impounded?).to be_truthy
        expect(impound_record.user).to eq user
        expect(impound_record.location).to be_blank
        # Doesn't include move update kind, because there is no location
        expect(impound_record.update_kinds).to eq valid_update_kinds

        impound_record_update.save
        expect(impound_record_update.resolved?).to be_truthy
        impound_record.reload
        expect(impound_record.resolved?).to be_truthy
        expect(impound_record.resolved_at).to be_within(1).of Time.current
        expect(impound_record.user_id).to eq user2.id
      end
      context "unregistered_parking_notification" do
        let(:parking_notification) do
          pn = FactoryBot.create(:unregistered_parking_notification,
            created_at: Time.current - 1.hour,
            organization: organization,
            user: user2,
            kind: "impound_notification")
          # Process parking_notification in the actual code path that creates the impound record
          ProcessParkingNotificationWorker.new.perform(pn.id)
          pn.reload
          pn
        end
        let(:bike) { parking_notification.bike }
        let!(:impound_record) { parking_notification.impound_record }
        # NOTE: This is permitted, but blocked in the controller.
        # Testing here to document and because maybe someday might want to error
        it "does not error" do
          bike.update(updated_at: Time.current)
          expect(bike.reload.impounded?).to be_truthy
          expect(bike.status_impounded?).to be_truthy
          expect(bike.created_by_parking_notification?).to be_truthy
          expect(impound_record.unregistered_bike?).to be_truthy
          expect(impound_record.creator&.id).to eq user2.id
          expect(impound_record.location).to be_blank
          expect(impound_record.status).to eq "current"
          expect(impound_record.to_coordinates).to eq parking_notification.to_coordinates
          # Doesn't include move update kind, because there is no location
          expect(impound_record.update_kinds).to eq(valid_update_kinds - ["retrieved_by_owner"])
          Sidekiq::Worker.clear_all
          expect {
            impound_record_update.save
          }.to change(ImpoundUpdateBikeWorker.jobs, :count).by 1
          ImpoundUpdateBikeWorker.drain
          expect(impound_record_update).to be_valid
          expect(impound_record_update)

          impound_record_update.save
          expect(impound_record_update.resolved?).to be_truthy
          impound_record.reload
          expect(impound_record.resolved?).to be_truthy
          expect(impound_record.resolved_at).to be_within(1).of Time.current
          expect(impound_record.user_id).to eq user2.id
          expect(impound_record.bike_id).to eq bike.id

          bike.reload
          expect(bike.deleted?).to be_falsey
          # It's still unregistered, nothing changed
          expect(bike.created_by_parking_notification?).to be_truthy
        end
        context "approved_claim" do
          let!(:impound_claim) do
            FactoryBot.create(:impound_claim_with_stolen_record,
              status: "submitting",
              organization: organization,
              created_at: Time.current - 1.hour,
              impound_record: impound_record)
          end
          let(:stolen_record) { impound_claim.stolen_record }
          let(:bike_submitting) { impound_claim.bike_submitting }
          let(:impound_record_update_approved) do
            impound_record.impound_record_updates.create(user: user2,
                                                         kind: "claim_approved", impound_claim: impound_claim)
          end
          it "associates with the approved claim" do
            expect(impound_claim.reload.status).to eq "submitting"
            expect(impound_claim.submitted?).to be_truthy
            expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - %w[move_location retrieved_by_owner])
            expect(impound_record_update_approved).to be_valid
            impound_claim.reload
            expect(impound_claim.bike_claimed_id).to eq bike.id
            expect(impound_claim.status).to eq "approved"
            expect(stolen_record.reload.recovered?).to be_falsey
            expect(impound_claim.stolen_record&.id).to eq stolen_record.id

            impound_record.reload
            expect(impound_record.unregistered_bike?).to be_truthy
            expect(impound_record.impound_claims.approved.pluck(:id)).to eq([impound_claim.id])
            # And now, can't be approved or denied, because already approved
            expect(impound_record.update_kinds).to eq valid_update_kinds

            bike_submitting.reload
            expect(bike_submitting.status_stolen?).to be_truthy
            bike.reload
            expect(bike.impounded?).to be_truthy
            expect(bike.status_impounded?).to be_truthy
            expect(bike.created_by_parking_notification?).to be_truthy
            expect(impound_record.creator&.id).to eq user2.id
            expect(impound_record.location).to be_blank
            expect(impound_record.status).to eq "current"
            expect(impound_record.impound_claim_retrieved?).to be_falsey

            impound_record_update.save
            expect(impound_record_update).to be_valid
            expect(impound_record_update.impound_claim_id).to be_blank
            Sidekiq::Worker.clear_all
            expect {
              impound_record_update.save
            }.to change(ImpoundUpdateBikeWorker.jobs, :count).by 1
            ImpoundUpdateBikeWorker.drain
            expect(impound_record_update.reload.resolved?).to be_truthy
            expect(impound_record_update.impound_claim_id).to eq impound_claim.id
            impound_claim.reload
            expect(impound_claim.status).to eq "retrieved"
            expect(impound_claim.bike_submitting_id).to eq bike_submitting.id
            expect(impound_claim.bike_claimed_id).to eq bike.id
            expect(impound_claim.stolen_record&.id).to eq stolen_record.id

            impound_record.reload
            expect(impound_record.resolved?).to be_truthy
            expect(impound_record.resolved_at).to be_within(1).of Time.current
            expect(impound_record.user_id).to eq user2.id
            expect(impound_record.impound_claim_retrieved?).to be_truthy

            bike.reload
            expect(bike.created_by_parking_notification?).to be_truthy
            expect(bike.deleted?).to be_truthy

            bike_submitting.reload
            expect(bike_submitting.status_stolen?).to be_falsey
            stolen_record.reload
            expect(stolen_record.recovered?).to be_truthy
          end
        end
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
      expect(impound_record.update_kinds).to eq(["note"])
    end
  end

  describe "impound_location" do
    let!(:location) { FactoryBot.create(:location, organization: organization, impound_location: true, default_impound_location: true) }
    let!(:location2) { FactoryBot.create(:location, organization: organization, impound_location: true) }
    let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, user: user, bike: bike, organization: organization) }
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
      expect {
        impound_record.update(updated_at: Time.current)
      }.to change(ImpoundUpdateBikeWorker.jobs, :count).by 1
      expect {
        impound_record.destroy
      }.to_not change(ImpoundUpdateBikeWorker.jobs, :count)
    end
  end

  describe "notification_notes_and_messages" do
    # This method is relevant because PSU puts serials into the notes from the parking notifications
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: organization) }
    let(:bike) { impound_record.bike }
    it "returns serial number" do
      expect(impound_record.parking_notification&.id).to be_blank
      expect(impound_record.notification_notes_and_messages).to be_blank
    end
    context "note and message" do
      let(:parking_notification1) do
        FactoryBot.create(:parking_notification, bike: bike, organization: organization, kind: "parked_incorrectly_notification",
                                                 internal_notes: "Internal note 1", created_at: Time.current - 1.month)
      end
      let!(:parking_notification2) do
        FactoryBot.create(:parking_notification, is_repeat: true, organization: organization, kind: "impound_notification", impound_record: impound_record,
                                                 initial_record_id: parking_notification1.id, internal_notes: "Internal note 2", message: "this is a message")
      end
      it "returns note and message" do
        impound_record.reload
        organization.reload
        expect(impound_record.parking_notification&.id).to eq parking_notification2.id
        parking_notification2.reload
        expect(parking_notification2.associated_notifications_including_self.map(&:id)).to match_array([parking_notification2.id, parking_notification1.id])
        expect(impound_record.notification_notes_and_messages).to match_array(["Internal note 1", "Internal note 2", "this is a message"])
      end
    end
  end

  describe "geocoding" do
    context "real geocoding" do
      include_context :geocoder_real
      let!(:state) { FactoryBot.create(:state_illinois) }
      let(:latitude) { 41.9202384 }
      let(:longitude) { -87.7158185 }
      let(:impound_record) { FactoryBot.build(:impound_record, street: "3554 W Shakespeare Ave, 60647") }
      it "geocodes if no address and if address changes" do
        VCR.use_cassette("impound_record-address_lookup") do
          impound_record.save
          impound_record.reload
          expect(impound_record.street).to eq "3554 W Shakespeare Ave"
          expect(impound_record.address).to eq "Chicago, IL 60647"
          expect(impound_record.address(force_show_address: true)).to eq "3554 W Shakespeare Ave, Chicago, IL 60647"
          expect(impound_record.latitude).to eq latitude
          expect(impound_record.longitude).to eq longitude
          expect(impound_record.valid?).to be_truthy
          expect(impound_record.id).to be_present
          expect(impound_record.state_id).to eq state.id
          expect(impound_record.country_id).to eq Country.united_states.id
          # It changes, so regeocodes
          impound_record.update(street: "2554 W Shakespeare ave")
          impound_record.reload
          expect(impound_record.address(force_show_address: true)).to eq "2554 W Shakespeare Ave, Chicago, IL 60647"
          expect(impound_record.latitude).to_not eq latitude
          expect(impound_record.longitude).to_not eq longitude
          # It does not change, no re-geocoding
          expect(Geohelper).to_not receive(:assignable_address_hash)
          impound_record.update(status: "retrieved_by_owner")
        end
      end
    end
    context "updating address" do
      # it "geocodes" do
      #   fail
      # end
    end
    context "no location" do
      let(:impound_record) { FactoryBot.create(:impound_record) }
      it "does not geocode" do
        impound_record.reload
        expect(impound_record.to_coordinates).to eq([nil, nil])
      end
    end
  end
end
