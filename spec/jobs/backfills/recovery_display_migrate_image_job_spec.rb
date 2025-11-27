require "rails_helper"

RSpec.describe Backfills::RecoveryDisplayMigrateImageJob, type: :job do
  let(:instance) { described_class.new }
  let(:recovery_display) { FactoryBot.create(:recovery_display) }

  describe "#perform" do
    it "attaches the image" do
      VCR.use_cassette("backfills-recovery_display_migrate_image_job") do
        expect(recovery_display.reload.photo.attached?).to be_falsey
        allow_any_instance_of(RecoveryDisplay).to receive(:image_url).and_return("https://files.bikeindex.org/uploads/Re/3223/recovery_3223.png")
        # recovery_display.image is blank, so stub skip_regeneration?
        allow(instance).to receive(:skip_regeneration?).and_return(false)
        instance.perform(recovery_display.id)
        expect(recovery_display.reload.photo.attached?).to be_truthy
        expect(recovery_display.photo_url).to be_present
      end
    end
    context "recovery display does not exist" do
      it "returns without error" do
        expect { instance.perform(999_999) }.not_to raise_error
      end
    end

    context "recovery display has no CarrierWave image" do
      it "returns without attaching photo" do
        expect(recovery_display.reload.photo.attached?).to be_falsey
        expect(recovery_display.image).to be_blank
        expect(instance.send(:skip_regeneration?, recovery_display, false)).to be_truthy
        instance.perform(recovery_display.id)
        expect(recovery_display.reload.photo.attached?).to be_falsey
      end
    end

    context "recovery display already has ActiveStorage photo" do
      before do
        recovery_display.photo.attach(
          io: StringIO.new("existing photo"),
          filename: "existing.jpg",
          content_type: "image/jpeg"
        )
      end

      it "does not replace the existing photo" do
        expect(recovery_display.photo.attached?).to be_truthy
        original_blob_id = recovery_display.photo.blob.id
        instance.perform(recovery_display.id)
        expect(recovery_display.reload.photo.blob.id).to eq(original_blob_id)
      end
    end
  end
end
