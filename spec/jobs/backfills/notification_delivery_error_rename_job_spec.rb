require "rails_helper"

RSpec.describe Backfills::NotificationDeliveryErrorRenameJob, type: :job do
  describe "perform" do
    def create_notification(delivery_error)
      FactoryBot.create(:notification, delivery_status: "delivery_failure", delivery_error:)
    end

    let!(:legacy) { create_notification("Postmark::InvalidEmailAddressError") }
    let!(:current) { create_notification("Postmark::InvalidEmailRequestError") }
    let!(:spam) { create_notification("Postmark::InactiveRecipientError") }

    it "renames only the legacy error" do
      expect(legacy.delivery_error_invalid?).to be_falsey

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(legacy.reload.delivery_error).to eq "Postmark::InvalidEmailRequestError"
      expect(legacy.delivery_error_invalid?).to be_truthy
      expect(current.reload.delivery_error).to eq "Postmark::InvalidEmailRequestError"
      expect(spam.reload.delivery_error).to eq "Postmark::InactiveRecipientError"
    end
  end
end
