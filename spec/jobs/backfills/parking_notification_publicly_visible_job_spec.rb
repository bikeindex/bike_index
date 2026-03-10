# frozen_string_literal: true

require "rails_helper"

RSpec.describe Backfills::ParkingNotificationPubliclyVisibleJob, type: :job do
  describe "perform" do
    let!(:parking_notification_hidden) { FactoryBot.create(:parking_notification) }
    let!(:parking_notification_shown) { FactoryBot.create(:parking_notification) }

    before do
      # Simulate pre-backfill state: set hide_address and clear publicly_visible_attribute
      parking_notification_hidden.update_columns(hide_address: true, publicly_visible_attribute: nil)
      parking_notification_shown.update_columns(hide_address: false, publicly_visible_attribute: nil)
    end

    it "sets publicly_visible_attribute based on hide_address" do
      expect(parking_notification_hidden.publicly_visible_attribute).to be_nil
      expect(parking_notification_shown.publicly_visible_attribute).to be_nil

      described_class.new.perform

      parking_notification_hidden.reload
      parking_notification_shown.reload
      expect(parking_notification_hidden.publicly_visible_attribute).to eq "postal_code"
      expect(parking_notification_shown.publicly_visible_attribute).to eq "street"
    end

    context "with already backfilled records" do
      it "skips records that already have publicly_visible_attribute" do
        parking_notification_shown.update_column(:publicly_visible_attribute,
          ParkingNotification::PUBLICLY_VISIBLE_ATTRIBUTE_ENUM[:city])

        described_class.new.perform

        parking_notification_hidden.reload
        parking_notification_shown.reload
        expect(parking_notification_hidden.publicly_visible_attribute).to eq "postal_code"
        expect(parking_notification_shown.publicly_visible_attribute).to eq "city"
      end
    end
  end
end
