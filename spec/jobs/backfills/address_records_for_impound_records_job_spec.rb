require "rails_helper"

RSpec.describe Backfills::AddressRecordsForImpoundRecordsJob, type: :job do
  let(:instance) { described_class.new }

  context "with legacy location attrs" do
    let!(:state) { FactoryBot.create(:state_illinois) }
    let(:impound_record) { FactoryBot.create(:impound_record) }

    let(:location_attrs) do
      {
        city: "Chicago",
        state_id: state.id,
        street: "1300 W 14th Pl",
        zipcode: "60608",
        country_id: Country.united_states_id,
        latitude: 41.8624488,
        longitude: -87.6591502
      }
    end

    before { impound_record.update_columns(location_attrs) }

    describe "build_or_create_for" do
      let(:target_attrs) do
        {
          region_record_id: state.id,
          region_string: nil,
          latitude: 41.8624488,
          longitude: -87.6591502,
          city: "Chicago",
          country_id: Country.united_states_id,
          street: "1300 W 14th Pl",
          postal_code: "60608",
          kind: "impounded_from",
          user_id: impound_record.user_id
        }
      end

      it "creates for chicago" do
        expect(impound_record.reload.address_record_id).to be_nil
        expect(AddressRecord.count).to eq 0

        expect do
          described_class.build_or_create_for(impound_record)
        end.to change(AddressRecord, :count).by 1
        expect(CallbackJob::AddressRecordUpdateAssociationsJob.jobs.count).to eq 0

        expect(impound_record.reload.address_record_id).to be_present
        expect(impound_record.address_record).to match_hash_indifferently target_attrs

        expect { described_class.build_or_create_for(impound_record) }.to_not change(AddressRecord, :count)
      end
    end

    describe "perform" do
      let(:impound_record_no_location) { FactoryBot.create(:impound_record) }

      before { impound_record_no_location }

      it "creates address_record for impound_records with location" do
        expect(described_class.iterable_scope.pluck(:id)).to match_array([impound_record.id])

        expect do
          instance.perform
          instance.perform
        end.to change(AddressRecord, :count).by 1

        expect(impound_record.reload.address_record_id).to be_present
        expect(impound_record_no_location.reload.address_record_id).to be_nil
      end
    end
  end

  describe "impound_record with impound_record_update to location" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[impound_bikes impound_bikes_locations]) }
    let(:user) { FactoryBot.create(:organization_user, organization:) }
    let!(:location) { FactoryBot.create(:location, organization:, impound_location: true) }
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization, user:, organization:) }

    before do
      impound_record.update_columns(address_record_id: nil)
      # Create move_location update
      FactoryBot.create(:impound_record_update, impound_record:, location:, kind: :move_location)
      impound_record.reload
    end

    it "assigns location address_record without creating a new one" do
      expect(location.address_record).to be_present
      initial_address_record_count = AddressRecord.count

      described_class.build_or_create_for(impound_record)

      expect(AddressRecord.count).to eq initial_address_record_count
      expect(impound_record.reload.address_record_id).to eq location.address_record_id
    end
  end

  describe "impound_record from parking_notification" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
    let(:parking_notification) do
      pn = FactoryBot.create(:parking_notification_organized, organization:, kind: "impound_notification")
      ProcessParkingNotificationJob.new.perform(pn.id)
      pn.reload
    end
    let(:impound_record) { parking_notification.impound_record }
    let(:pn_location_attrs) do
      {
        street: "500 Main St",
        city: "Oakland",
        zipcode: "94612",
        latitude: 37.8044,
        longitude: -122.2712,
        country_id: Country.united_states_id
      }
    end

    before { impound_record.update_columns(pn_location_attrs.merge(address_record_id: nil)) }

    it "creates address_record matching parking notification location" do
      expect(impound_record.street).to eq "500 Main St"
      expect(impound_record.city).to eq "Oakland"

      expect { described_class.build_or_create_for(impound_record) }.to change(AddressRecord, :count).by 1

      expect(impound_record.reload.address_record).to have_attributes(
        kind: "impounded_from",
        street: "500 Main St",
        city: "Oakland",
        postal_code: "94612"
      )
    end
  end

  describe "impound_record from parking_notification then moved to location" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[parking_notifications impound_bikes impound_bikes_locations]) }
    let!(:location) { FactoryBot.create(:location, organization:, impound_location: true) }
    let(:parking_notification) do
      pn = FactoryBot.create(:parking_notification_organized, organization:, kind: "impound_notification")
      ProcessParkingNotificationJob.new.perform(pn.id)
      pn.reload
    end
    let(:impound_record) { parking_notification.impound_record }
    let(:pn_location_attrs) do
      {
        street: "500 Main St",
        city: "Oakland",
        zipcode: "94612",
        latitude: 37.8044,
        longitude: -122.2712,
        country_id: Country.united_states_id
      }
    end

    before do
      impound_record.update_columns(pn_location_attrs.merge(address_record_id: nil))
      # Create move_location update
      FactoryBot.create(:impound_record_update, impound_record:, location:, kind: :move_location)
      # Reset address_record_id after update (simulating legacy data without address_record)
      impound_record.update_columns(address_record_id: nil)
      impound_record.reload
    end

    it "creates impounded_from address_record but references location address_record" do
      expect(location.address_record).to be_present
      expect(impound_record.street).to eq "500 Main St"
      expect(impound_record.address_record_id).to be_nil

      expect { described_class.build_or_create_for(impound_record) }.to change(AddressRecord, :count).by 1

      impound_record.reload
      # impound_record.address_record_id should be the location's address_record
      expect(impound_record.address_record_id).to eq location.address_record_id

      # But an impounded_from address_record should exist with the parking notification location
      impounded_from_record = AddressRecord.find_by(kind: :impounded_from, street: "500 Main St", city: "Oakland")
      expect(impounded_from_record).to be_present
      expect(impounded_from_record.id).to_not eq location.address_record_id
    end
  end
end
