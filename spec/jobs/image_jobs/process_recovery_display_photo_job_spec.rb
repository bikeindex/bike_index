require "rails_helper"

RSpec.describe ImageJobs::ProcessRecoveryDisplayPhotoJob, type: :job do
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
        expect do
          described_class.new.perform(recovery_display.id)
        end.to_not change(described_class.jobs, :count)
        expect(recovery_display.reload.photo_processed.attached?).to be_truthy
      end

      context "when another job attaches a processed photo while this one processes" do
        let!(:other_blob) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("other"), filename: "other.jpg") }

        it "keeps the other job's photo" do
          allow(ImageProcessing::Vips).to receive(:source).and_wrap_original do |original, *args|
            RecoveryDisplay.find(recovery_display.id).photo_processed.attach(other_blob)
            original.call(*args)
          end

          expect do
            described_class.new.perform(recovery_display.id)
          end.to_not change(ActiveStorage::Blob, :count)
          expect(ActiveStorage::Attachment.where(record: recovery_display, name: "photo_processed")
            .pluck(:blob_id)).to eq([other_blob.id])
        end
      end
    end

    context "with remote_photo_url" do
      let(:remote_url) { "https://files.bikeindex.org/uploads/Re/3223/recovery_3223.png" }

      it "downloads and attaches the photo, then processes it", :vcr do
        VCR.use_cassette("recovery_display-process_photo_job") do
          expect(recovery_display.photo.attached?).to be_falsey
          expect(recovery_display.photo_processed?).to be_falsey

          expect do
            described_class.new.perform(recovery_display.id, remote_url)
          end.to_not change(described_class.jobs, :count)

          expect(recovery_display.reload.photo.attached?).to be_truthy
          expect(recovery_display.photo.filename.to_s).to eq "recovery-#{recovery_display.id}"
          expect(recovery_display.photo_processed.attached?).to be_truthy
          expect(recovery_display.photo_processed?).to be_truthy
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

        expect do
          described_class.new.perform(recovery_display.id, nil, true)
        end.to_not change(described_class.jobs, :count)

        expect(recovery_display.reload.photo_processed.blob.id).not_to eq(original_blob_id)
        expect(recovery_display.photo_processed?).to be_truthy
      end
    end
  end
end
