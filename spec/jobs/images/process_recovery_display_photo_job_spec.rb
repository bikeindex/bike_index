require "rails_helper"

RSpec.describe Images::ProcessRecoveryDisplayPhotoJob, type: :job do
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

# RSpec.describe Images::RecoveryDisplayProcessor do
#   let(:recovery_display) { FactoryBot.create(:recovery_display) }

#   describe ".process_photo" do
#     context "without photo attached" do
#       it "returns nil" do
#         expect(described_class.process_photo(recovery_display)).to be_nil
#       end
#     end

#     context "with photo attached" do
#       before do
#         recovery_display.photo.attach(
#           io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
#           filename: "bike.jpg",
#           content_type: "image/jpeg"
#         )
#       end

#       it "creates a processed photo" do
#         expect(recovery_display.photo_processed.attached?).to be_falsey
#         described_class.process_photo(recovery_display)
#         expect(recovery_display.reload.photo_processed.attached?).to be_truthy
#       end

#       it "does not regenerate if already processed" do
#         described_class.process_photo(recovery_display)
#         original_blob_id = recovery_display.photo_processed.blob.id
#         described_class.process_photo(recovery_display)
#         expect(recovery_display.reload.photo_processed.blob.id).to eq(original_blob_id)
#       end

#       it "regenerates if force_regenerate is true" do
#         described_class.process_photo(recovery_display)
#         original_blob_id = recovery_display.photo_processed.blob.id
#         described_class.process_photo(recovery_display, force_regenerate: true)
#         expect(recovery_display.reload.photo_processed.blob.id).not_to eq(original_blob_id)
#       end
#     end
#   end
# end
