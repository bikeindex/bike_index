require "rails_helper"

RSpec.describe Backfills::ImpoundedFromAddressRecordJob, type: :job do
  describe "perform" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: %w[parking_notifications impound_bikes impound_bikes_locations])
    end
    let!(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, organization:, impound_location: true, default_impound_location: true) }
    let(:initial_notification) do
      FactoryBot.create(:parking_notification_organized, organization:, kind: "appears_abandoned_notification",
        latitude: 37.8044, longitude: -122.2712, street: "1 Frank H Ogawa Plaza", city: "Oakland", use_entered_address: "1")
    end
    let(:parking_notification) do
      FactoryBot.create(:parking_notification_organized, organization:, bike: initial_notification.bike, initial_record: initial_notification,
        kind: "impound_notification", latitude: 37.7749, longitude: -122.4194, street: "1 Market St", city: "San Francisco", use_entered_address: "1")
    end
    let(:impound_record) { FactoryBot.create(:impound_record, organization:, bike: parking_notification.bike, updated_at: Time.current - 1.week) }
    # How ProcessParkingNotificationJob left them: created at the default location, the whole chain linked afterward
    before { [initial_notification, parking_notification].each { it.update_column(:impound_record_id, impound_record.id) } }

    it "builds the impounded-from address from the parking notification, keeping the location" do
      expect(impound_record.reload.impounded_from_address_record_id).to be_nil
      updated_at = impound_record.updated_at

      expect {
        Sidekiq::Testing.inline! { described_class.perform_async }
      }.not_to change(ProcessImpoundUpdatesJob.jobs, :count)

      impound_record.reload
      expect(impound_record.impounded_from_address_record).to have_attributes(kind: "impounded_from", street: "1 Market St", city: "San Francisco")
      expect(impound_record.address_record_id).to eq location.address_record_id
      expect(impound_record.updated_at).to eq updated_at
    end

    context "when only an earlier notification in the chain has coordinates" do
      before { parking_notification.update_columns(latitude: nil, longitude: nil) }

      it "skips it" do
        Sidekiq::Testing.inline! { described_class.perform_async }
        expect(impound_record.reload.impounded_from_address_record_id).to be_nil
      end
    end
  end
end
