require "rails_helper"

RSpec.describe Backfills::StolenAlertBlobBinxDataJob, type: :job do
  def create_blob(filename, metadata: {})
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("photo"), filename:, metadata:,
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

    context "metadata from before binx_data" do
      let!(:alert_image) { create_blob("stolen-42-four_by_five.jpeg", metadata: {"image_id" => 7, "identified" => true}) }
      let!(:removed_alert_image) { create_blob("stolen-8-four_by_five.jpeg", metadata: {"removed" => true}) }

      it "migrates image_id and removed, and leaves ActiveStorage's own keys" do
        Sidekiq::Testing.inline! { described_class.perform_async }

        expect(alert_image.reload.binx_data).to eq({"stolen_record_id" => 42, "image_id" => 7})
        expect(alert_image.metadata).to eq({"image_id" => 7, "identified" => true})
        expect(removed_alert_image.reload.binx_data).to eq({"stolen_record_id" => 8, "removed" => true})
      end
    end
  end
end
