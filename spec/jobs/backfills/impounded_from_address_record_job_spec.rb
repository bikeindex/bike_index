require "rails_helper"

RSpec.describe Backfills::ImpoundedFromAddressRecordJob, type: :job do
  describe "perform" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: %w[parking_notifications impound_bikes impound_bikes_locations])
    end
    let!(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, organization:, impound_location: true, default_impound_location: true) }
    let(:parking_notification) do
      FactoryBot.create(:parking_notification_organized, organization:, kind: "impound_notification",
        latitude: 37.7749, longitude: -122.4194, street: "1 Market St", city: "San Francisco", use_entered_address: "1")
    end
    let(:impound_record) { FactoryBot.create(:impound_record, organization:, bike: parking_notification.bike, updated_at: Time.current - 1.week) }
    # How ProcessParkingNotificationJob left them: created at the default location, the notification linked afterward
    before { parking_notification.update_column(:impound_record_id, impound_record.id) }

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
  end
end
