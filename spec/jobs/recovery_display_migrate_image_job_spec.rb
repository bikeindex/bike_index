require "rails_helper"

RSpec.describe RecoveryDisplayMigrateImageJob, type: :job do
  let(:recovery_display) { FactoryBot.create(:recovery_display) }

  describe "#perform" do
    context "recovery display does not exist" do
      it "returns without error" do
        expect { RecoveryDisplayMigrateImageJob.new.perform(999_999) }.not_to raise_error
      end
    end

    context "recovery display has no CarrierWave image" do
      it "returns without attaching photo" do
        expect(recovery_display.photo.attached?).to be_falsey
        RecoveryDisplayMigrateImageJob.new.perform(recovery_display.id)
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
        RecoveryDisplayMigrateImageJob.new.perform(recovery_display.id)
        expect(recovery_display.reload.photo.blob.id).to eq(original_blob_id)
      end
    end
  end
end
