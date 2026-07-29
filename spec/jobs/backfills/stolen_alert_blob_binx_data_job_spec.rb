require "rails_helper"

RSpec.describe Backfills::StolenAlertBlobBinxDataJob, type: :job do
  def create_blob(filename)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("photo"), filename:,
      content_type: "image/jpeg")
  end

  describe "perform" do
    let!(:alert_image) { create_blob("stolen-42-opengraph.jpeg") }
    let!(:stamped_alert_image) { create_blob("stolen-9-square.jpeg") }
    # A file the user named, not one StolenProcessor minted
    let!(:user_upload) { create_blob("stolen-bike.jpg") }

    it "stamps the alert images the filename identifies" do
      stamped_alert_image.update!(binx_data: {"stolen_record_id" => 9})

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(alert_image.reload.binx_data).to eq({"stolen_record_id" => 42})
      expect(stamped_alert_image.reload.binx_data).to eq({"stolen_record_id" => 9})
      expect(user_upload.reload.binx_data).to be_nil
    end
  end
end
