require "rails_helper"

RSpec.describe Images::RecoveryDisplayProcessor do
  let(:recovery_display) { FactoryBot.create(:recovery_display) }

  describe ".process_photo" do
    context "without photo attached" do
      it "returns nil" do
        expect(described_class.process_photo(recovery_display)).to be_nil
      end
    end

    context "with photo attached" do
      before do
        recovery_display.photo.attach(
          io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
          filename: "bike.jpg",
          content_type: "image/jpeg"
        )
      end

      it "creates a processed photo" do
        expect(recovery_display.photo_processed.attached?).to be_falsey
        described_class.process_photo(recovery_display)
        expect(recovery_display.reload.photo_processed.attached?).to be_truthy
      end

      it "does not regenerate if already processed" do
        described_class.process_photo(recovery_display)
        original_blob_id = recovery_display.photo_processed.blob.id
        described_class.process_photo(recovery_display)
        expect(recovery_display.reload.photo_processed.blob.id).to eq(original_blob_id)
      end

      it "regenerates if force_regenerate is true" do
        described_class.process_photo(recovery_display)
        original_blob_id = recovery_display.photo_processed.blob.id
        described_class.process_photo(recovery_display, force_regenerate: true)
        expect(recovery_display.reload.photo_processed.blob.id).not_to eq(original_blob_id)
      end
    end
  end
end
