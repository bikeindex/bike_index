require "rails_helper"

RSpec.describe ImpoundRecord, type: :model do
  it_behaves_like "default_currencyable"
  it_behaves_like "address_recorded"

  describe "factory" do
    context "with_address_record" do
      let(:impound_record) { FactoryBot.create(:impound_record, :with_organization, :with_address_record, address_in: :chicago) }
      it "is valid with address_record" do
        expect(impound_record).to be_valid
        expect(impound_record.address_record).to be_present
        expect(impound_record.address_record.kind).to eq "impounded_from"
        expect(impound_record.address_record.city).to eq "Chicago"
        expect(impound_record.address_record.region_record.abbreviation).to eq "IL"
        expect(impound_record.address_record.country).to eq Country.united_states
      end
    end

    context "with_address_record and different address" do
      let(:impound_record) { FactoryBot.create(:impound_record, :with_organization, :with_address_record, address_in: :new_york) }
      it "uses the specified address" do
        expect(impound_record).to be_valid
        expect(impound_record.address_record.city).to eq "New York"
        expect(impound_record.address_record.region_record.abbreviation).to eq "NY"
      end
    end
  end

  let!(:bike) { FactoryBot.create(:bike, created_at: Time.current - 1.day) }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "impound_bikes") }
  let(:impound_configuration) { organization.fetch_impound_configuration }
  let(:user) { FactoryBot.create(:organization_user, organization: organization) }
  let(:organization_user) { FactoryBot.create(:organization_user, organization: organization) }

  describe "validations" do
    it "marks the bike impounded only once" do
      expect(Bike.impounded.pluck(:id)).to eq([])
      expect(organization.enabled?("impound_bikes")).to be_truthy
      organization.reload
      expect(organization.enabled?("impound_bikes")).to be_truthy
      expect(bike.impounded?).to be_falsey
      bike.impound_records.create(user: user, bike: bike, organization: organization)
      expect(bike.impound_records.count).to eq 1
      bike.update(updated_at: Time.current)
      expect(bike.reload.impounded?).to be_truthy
      expect(bike.status_found?).to be_falsey
      expect(bike.impound_records.count).to eq 1
      impound_record = bike.current_impound_record
      expect(impound_record.organization).to eq organization
      expect(impound_record.user).to eq user
      expect(impound_record.current?).to be_truthy
      expect(Bike.impounded.pluck(:id)).to eq([bike.id])
      expect(organization.impound_records.bikes.pluck(:id)).to eq([bike.id])
      expect(impound_record.kind).to eq "impounded"
      expect(impound_record.impounded_at).to be_within(1).of impound_record.created_at
      impound_record.update(impounded_at: Time.current - 11.years)
      expect(impound_record.reload.impounded_at).to be_within(1).of impound_record.created_at
    end
    context "bike already impounded" do
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike, display_id: "fasdfasdf1", display_id_prefix: "fasdfasdf", display_id_integer: 1) }
      it "errors" do
        expect(impound_record.reload.to_coordinates).to eq([nil, nil])
        expect(impound_record.organization_id).to be_blank
        # Blank out the display id for unorganized records
        expect(impound_record.display_id).to be_blank
        expect(impound_record.display_id_prefix).to be_blank
        expect(impound_record.display_id_integer).to be_blank
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
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, user: user, bike: bike, organization: organization, display_id: "v8xcv833") }
      let!(:user2) { FactoryBot.create(:organization_user, organization: organization) }
      let(:impound_record_update) { FactoryBot.build(:impound_record_update, impound_record: impound_record, user: user2, kind: "retrieved_by_owner") }
      let(:valid_update_kinds) { ImpoundRecordUpdate.kinds - %w[move_location claim_approved claim_denied expired] }
      it "updates the record and the user" do
        ProcessImpoundUpdatesJob.new.perform(impound_record.id)
        bike.reload
        expect(bike.impounded?).to be_truthy
        expect(bike.status_impounded?).to be_truthy
        expect(impound_record.reload.display_id).to eq "v8xcv833"
        expect(impound_record.user).to eq user
        expect(impound_record.location).to be_blank
        # Doesn't include move update kind, because there is no location
        expect(impound_record.update_kinds).to eq valid_update_kinds
        expect(impound_record.update_multi_kinds).to eq(impound_record.update_kinds - ["current"])

        impound_record_update.save
        expect(impound_record_update.resolved?).to be_truthy
        impound_record.reload
        expect(impound_record.resolved?).to be_truthy
        expect(impound_record.resolved_at).to be_within(1).of Time.current
        expect(impound_record.user_id).to eq user2.id
      end
      context "unregistered_parking_notification" do
        let(:parking_notification) do
          pn = FactoryBot.create(:parking_notification_unregistered,
            created_at: Time.current - 1.hour,
            organization: organization,
            user: user2,
            kind: "impound_notification")
          # Process parking_notification in the actual code path that creates the impound record
          ProcessParkingNotificationJob.new.perform(pn.id)
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
          expect(bike.status_found?).to be_falsey
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          expect(bike.authorized?(user)).to be_truthy
          impound_record.reload
          expect(impound_record.send(:calculated_unregistered_bike?)).to be_truthy
          expect(impound_record.unregistered_bike?).to be_truthy
          expect(impound_record.creator&.id).to eq user2.id
          expect(impound_record.location).to be_blank
          expect(impound_record.status).to eq "current"
          expect(impound_record.to_coordinates).to eq parking_notification.to_coordinates
          expect(impound_record.authorized?(user)).to be_truthy
          expect(impound_record.authorized?(organization_user)).to be_truthy
          # Doesn't include move update kind, because there is no location
          expect(impound_record.update_kinds).to eq(valid_update_kinds - ["retrieved_by_owner"])
          expect(impound_record.update_multi_kinds).to eq(impound_record.update_kinds - %w[current expired])
          Sidekiq::Job.clear_all
          expect {
            impound_record_update.save
          }.to change(ProcessImpoundUpdatesJob.jobs, :count).by 1
          ProcessImpoundUpdatesJob.drain
          expect(impound_record_update).to be_valid
          expect(impound_record.update_multi_kinds).to eq(["note"])

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
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          expect(bike.status).to eq "status_with_owner"
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
          let(:valid_multi_update_claim_kinds) { %w[note claim_approved claim_denied] }
          it "associates with the approved claim" do
            expect(impound_claim.reload.status).to eq "submitting"
            expect(impound_claim.submitted?).to be_truthy
            expect(impound_record.update_kinds).to eq(ImpoundRecordUpdate.kinds - %w[move_location retrieved_by_owner expired])
            expect(impound_record.update_multi_kinds).to eq valid_multi_update_claim_kinds
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
            expect(impound_record.update_multi_kinds).to eq(%w[retrieved_by_owner note])

            bike_submitting.reload
            expect(bike_submitting.status_stolen?).to be_truthy
            bike.reload
            expect(bike.impounded?).to be_truthy
            expect(bike.status_impounded?).to be_truthy
            expect(bike.creator_unregistered_parking_notification?).to be_truthy
            expect(impound_record.creator&.id).to eq user2.id
            expect(impound_record.location).to be_blank
            expect(impound_record.status).to eq "current"
            expect(impound_record.impound_claim_retrieved?).to be_falsey

            impound_record_update.save
            expect(impound_record_update).to be_valid
            expect(impound_record_update.impound_claim_id).to be_blank
            Sidekiq::Job.clear_all
            expect {
              impound_record_update.save
            }.to change(ProcessImpoundUpdatesJob.jobs, :count).by 1
            ProcessImpoundUpdatesJob.drain
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
            expect(bike.creator_unregistered_parking_notification?).to be_truthy
            expect(bike.deleted?).to be_truthy

            bike_submitting.reload
            expect(bike_submitting.status).to eq "status_with_owner"
            stolen_record.reload
            expect(stolen_record.recovered?).to be_truthy

            expect(parking_notification.reload.status).to eq "impounded_retrieved"
            expect(parking_notification.retrieved_kind).to be_blank
            expect(parking_notification.resolved_at).to be_within(5).of Time.current
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
    let!(:location) { FactoryBot.create(:location, :with_address_record, organization: organization, impound_location: true, default_impound_location: true) }
    let!(:location2) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, organization: organization, impound_location: true) }
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

    context "with impounded_from address_record" do
      let(:impounded_from_address) { FactoryBot.create(:address_record) }
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, user:, bike:, organization:, address_record: impounded_from_address) }
      it "updates address_record_id to location's address_record_id without deleting impounded_from" do
        location2.reload
        expect(location2.address_record).to be_present
        expect(impound_record.reload.address_record_id).to eq impounded_from_address.id
        expect(impound_record.location).to eq location

        impound_record_update.save
        impound_record.reload

        expect(impound_record.location).to eq location2
        expect(impound_record.address_record_id).to eq location2.address_record_id
        expect(AddressRecord.exists?(impounded_from_address.id)).to be_truthy
      end
    end
  end

  describe "update_associations" do
    let(:impound_record) { FactoryBot.build(:impound_record) }
    it "enqueues for create and update, not destroy" do
      expect {
        impound_record.save
      }.to change(ProcessImpoundUpdatesJob.jobs, :count).by 1
      expect {
        impound_record.update(updated_at: Time.current)
      }.to change(ProcessImpoundUpdatesJob.jobs, :count).by 1
      expect {
        impound_record.destroy
      }.to_not change(ProcessImpoundUpdatesJob.jobs, :count)
    end
  end

  describe "authorized?" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, created_at: Time.current - 3.hours) }
    let(:bike_user) { bike.user }
    let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, user:, bike:, organization:) }
    let(:organization_role2) { FactoryBot.create(:organization_role_claimed, user:) }
    let(:organization2) { organization_role2.organization }
    let(:superuser) { User.new(superuser: true) }
    it "is not authorized by bike_user" do
      expect(impound_record.reload.organized?).to be_truthy
      bike.reload
      expect(bike_user).to be_present
      expect(bike.send(:authorization_requires_impound_organization?)).to be_truthy
      expect(bike.send(:editable_organization_ids)).to eq([organization.id])
      expect(bike.authorized?(bike_user)).to be_falsey
      expect(bike.authorized?(user)).to be_truthy
      expect(bike.current_impound_record).to be_present
      expect(bike.current_impound_record.authorized?(bike.user)).to be_falsey
      expect(bike.current_impound_record.authorized?(user)).to be_truthy

      expect(bike.authorized_by_organization?(u: user)).to be_truthy
      expect(bike.authorized_by_organization?(u: user, org: organization)).to be_truthy
      expect(organization2.users.pluck(:id)).to eq([user.id])
      expect(bike.authorized_by_organization?(u: user, org: organization2)).to be_falsey

      expect(bike.authorized?(superuser)).to be_truthy
      expect(bike.authorized?(superuser, no_superuser_override: true)).to be_falsey
    end

    context "without organization" do
      let(:impound_record) { FactoryBot.create(:impound_record, user:, bike:) }
      # Impounding a bike doesn't give users the ability to override ownership access -
      # only organization impounded records
      it "authorized by bike_user" do
        expect(impound_record.reload.organized?).to be_falsey
        bike.reload
        expect(bike_user).to be_present
        expect(bike.send(:authorization_requires_impound_organization?)).to be_falsey
        expect(bike.send(:editable_organization_ids)).to eq([])
        expect(bike.authorized?(bike_user)).to be_truthy
        expect(bike.authorized?(user)).to be_falsey
        expect(bike.current_impound_record).to be_present
        expect(bike.current_impound_record.authorized?(bike.user)).to be_falsey
        expect(bike.current_impound_record.authorized?(user)).to be_truthy

        expect(bike.authorized_by_organization?(u: user)).to be_falsey
        expect(bike.authorized_by_organization?(u: user, org: organization)).to be_falsey

        expect(bike.authorized?(superuser)).to be_truthy
        expect(bike.authorized?(superuser, no_superuser_override: true)).to be_falsey
      end
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
      let(:impound_record_update) { FactoryBot.create(:impound_record_update, impound_record: impound_record, kind: "retrieved_by_owner") }
      it "returns note and message" do
        ProcessImpoundUpdatesJob.new.perform(impound_record.id)
        ProcessParkingNotificationJob.new.perform(parking_notification2.id)
        impound_record.reload
        organization.reload
        expect(impound_record.parking_notification&.id).to eq parking_notification2.id
        parking_notification2.reload
        expect(parking_notification2.associated_notifications_including_self.map(&:id)).to match_array([parking_notification2.id, parking_notification1.id])
        expect(impound_record.notification_notes_and_messages).to match_array(["Internal note 1", "Internal note 2", "this is a message"])
        expect(bike.reload.status).to eq "status_impounded"
        expect(parking_notification2.reload.status).to eq "impounded"
        resolved_at = parking_notification2.resolved_at
        expect(parking_notification2.resolved_at).to be_within(5).of resolved_at
        expect(parking_notification2.retrieved_kind).to be_blank

        expect(parking_notification1.reload.status).to eq "replaced"
        expect(parking_notification1.resolved_at).to be_within(5).of resolved_at
        # Trigger worker for impound_record_update, also associated pprocessing of parking notifications
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! { impound_record_update.reload }
        expect(bike.reload.status).to eq "status_with_owner"
        expect(parking_notification1.reload.status).to eq "replaced"
        expect(parking_notification1.resolved_at).to be_within(5).of resolved_at
        expect(parking_notification1.retrieved_kind).to be_blank
        expect(parking_notification2.reload.status).to eq "impounded_retrieved"
        expect(parking_notification2.resolved_at).to be_within(5).of resolved_at
        expect(parking_notification2.retrieved_kind).to be_blank

        # Also test first and last notification here, just in case
        expect(ParkingNotification.first_notification.pluck(:id)).to eq([parking_notification1.id])
        expect(ParkingNotification.not_replaced.pluck(:id)).to eq([parking_notification2.id])
      end
    end
  end

  describe "geocoding" do
    context "real geocoding" do
      include_context :geocoder_real
      let!(:state) { State.find_or_create_by(name: "Illinois", abbreviation: "IL", country: Country.united_states) }
      let(:latitude) { 41.9202384 }
      let(:longitude) { -87.7158185 }
      let(:impound_record) { FactoryBot.build(:impound_record, street: "3554 W Shakespeare Ave, 60647") }
      # TODO: Fix this - #2922 - Something with the vcr cassette
      xit "geocodes if no address and if address changes" do
        VCR.use_cassette("impound_record-address_lookup") do
          impound_record.save
          impound_record.reload
          expect(impound_record.street).to eq "3554 West Shakespeare Avenue"
          expect(impound_record.address).to eq "Chicago, IL 60647"
          expect(impound_record.address(force_show_address: true)).to eq "3554 West Shakespeare Avenue, Chicago, IL 60647"
          expect(impound_record.address(force_show_address: true, country: [:skip_default])).to eq "3554 West Shakespeare Avenue, Chicago, IL 60647"
          expect(impound_record.latitude).to eq latitude
          expect(impound_record.longitude).to eq longitude
          expect(impound_record.valid?).to be_truthy
          expect(impound_record.id).to be_present
          expect(impound_record.state_id).to eq state.id
          expect(impound_record.country_id).to eq Country.united_states.id
          # It changes, so regeocodes
          impound_record.update(street: "2554 West Shakespeare ave")
          impound_record.reload
          expect(impound_record.address(force_show_address: true)).to eq "2554 West Shakespeare Avenue, Chicago, IL 60647"
          expect(impound_record.latitude).to_not eq latitude
          expect(impound_record.longitude).to_not eq longitude
          # It does not change, no re-geocoding
          expect(GeocodeHelper).to_not receive(:assignable_address_hash_for)
          impound_record.update(status: "retrieved_by_owner")
        end
      end
    end
    context "no location" do
      let(:impound_record) { FactoryBot.create(:impound_record) }
      it "does not geocode" do
        impound_record.reload
        expect(impound_record.to_coordinates).to eq([nil, nil])
      end
    end
  end

  describe "set_calculated_display_id" do
    let(:impound_record) { ImpoundRecord.new(organization: organization) }
    let(:update_multi_kinds) { %w[retrieved_by_owner removed_from_bike_index transferred_to_new_owner note] }
    it "is 1" do
      expect(impound_record.send(:set_calculated_display_id)).to eq "1"
      expect(impound_record.update_kinds).to eq(["current"] + update_multi_kinds)
      expect(impound_record.update_multi_kinds).to eq update_multi_kinds
    end
    context "existing impound_record" do
      let!(:impound_record_existing) { FactoryBot.create(:impound_record_with_organization, organization: organization, display_id_prefix: "asdfasdf", display_id_integer: 2222) }
      it "is 1" do
        impound_configuration.update(expiration_period_days: 222)
        expect(impound_record_existing.reload.display_id_integer).to eq 2222
        expect(impound_record_existing.display_id_prefix).to eq "asdfasdf"
        expect(impound_record_existing.display_id).to eq "asdfasdf2222"
        expect(impound_configuration.display_id_prefix).to eq nil
        expect(impound_configuration.calculated_display_id_next_integer).to eq 1
        expect(impound_record.send(:set_calculated_display_id)).to eq "1"
        expect(impound_record.display_id).to eq "1" # it's set, but not stored
        # it doesn't respect unstored records
        impound_record2 = FactoryBot.create(:impound_record_with_organization, organization: organization)
        expect(impound_record2.display_id).to eq "1"
        # The og record updates!
        expect(impound_record.send(:set_calculated_display_id)).to eq "2"
        expect(impound_record.update_kinds).to eq(["current"] + update_multi_kinds)
        expect(impound_record.update_multi_kinds).to eq update_multi_kinds
      end
    end
  end

  describe "calculated_unregistered_bike?" do
    let(:bike) { FactoryBot.create(:bike, created_at: time, status: "status_impounded") }
    let!(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    let(:impound_record) { FactoryBot.create(:impound_record, created_at: impounded_time, bike: bike) }
    let(:time) { Time.current - 1.week }
    let(:impounded_time) { time + 1.hour }
    before { bike.reload }
    it "is falsey" do
      expect(Ownership.where(bike_id: bike.id).count).to eq 1
      expect(bike.current_ownership.status).to eq "status_with_owner"
      expect(bike.created_by_notification_or_impounding?).to be_falsey
      expect(impound_record.send(:calculated_unregistered_bike?)).to be_falsey
    end
    context "status_impounded" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, status: "status_impounded") }
      it "is truthy if bike creation state is status_impounded" do
        expect(Ownership.where(bike_id: bike.id).count).to eq 1
        expect(bike.current_ownership.status).to eq "status_impounded"
        expect(bike.created_by_notification_or_impounding?).to be_truthy
        expect(impound_record.reload.send(:calculated_unregistered_bike?)).to be_truthy
      end
      context "impound record earlier?" do
        let(:impounded_time) { time - 1.minute }
        it "is truthy" do
          expect(impound_record.send(:calculated_unregistered_bike?)).to be_truthy
        end
      end
      context "impound_record created at a vastly different time" do
        let(:impounded_time) { time + 1.day }
        it "is falsey" do
          expect(impound_record.send(:calculated_unregistered_bike?)).to be_falsey
        end
      end
    end
  end
end
