require "rails_helper"

RSpec.describe RecoveryDisplay::ProcessPhotoJob, type: :job do
  let(:recovery_display) { FactoryBot.create(:recovery_display) }

  describe "#perform" do
    context "recovery display does not exist" do
      it "returns without error" do
        expect { described_class.new.perform(999_999) }.not_to raise_error
      end
    end

    context "recovery display has photo" do
      before do
        recovery_display.photo.attach(
          io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
          filename: "bike.jpg",
          content_type: "image/jpeg"
        )
      end

      it "processes the photo" do
        expect(recovery_display.photo_processed.attached?).to be_falsey
        described_class.new.perform(recovery_display.id)
        expect(recovery_display.reload.photo_processed.attached?).to be_truthy
      end
    end

    context "with remote_photo_url" do
      let(:remote_url) { "https://files.bikeindex.org/uploads/Re/3223/recovery_3223.png" }

      it "downloads and attaches the photo, then processes it", :vcr do
        VCR.use_cassette("recovery_display-process_photo_job") do
          expect(recovery_display.photo.attached?).to be_falsey

          described_class.new.perform(recovery_display.id, remote_url)

          recovery_display.reload
          expect(recovery_display.photo.attached?).to be_truthy
          expect(recovery_display.photo.filename.to_s).to eq "recovery_3223.png"
          expect(recovery_display.photo_processed.attached?).to be_truthy
        end
      end
    end

    context "with force_regenerate" do
      before do
        recovery_display.photo.attach(
          io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
          filename: "bike.jpg",
          content_type: "image/jpeg"
        )
        described_class.new.perform(recovery_display.id)
      end

      it "regenerates the processed photo" do
        original_blob_id = recovery_display.reload.photo_processed.blob.id
        described_class.new.perform(recovery_display.id, nil, true)
        expect(recovery_display.reload.photo_processed.blob.id).not_to eq(original_blob_id)
      end
    end
  end
end
