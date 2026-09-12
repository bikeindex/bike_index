require "rails_helper"

RSpec.describe Backfills::HotSheetDeliveryStatusJob, type: :job do
  describe "perform" do
    let!(:delivered) { FactoryBot.create(:hot_sheet, delivery_status_legacy: "email_success") }
    let!(:unsent) { FactoryBot.create(:hot_sheet) }
    let!(:redelivered) do
      FactoryBot.create(:hot_sheet, delivery_status_legacy: "email_success",
        delivery_status: "delivery_partial_success")
    end

    it "settles the sheets that delivered, and leaves the rest" do
      expect(delivered.delivery_settled?).to be_falsey

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(delivered.reload.delivery_status).to eq "delivery_success"
      expect(delivered.delivery_settled?).to be_truthy
      expect(unsent.reload.delivery_status).to eq "delivery_pending"
      expect(redelivered.reload.delivery_status).to eq "delivery_partial_success"
    end
  end
end
