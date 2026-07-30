require "rails_helper"

RSpec.describe BikeJobs::RemoveOrphanedImagesJob, type: :lib do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue, frequency and retry" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 20.hours
    expect(described_class.sidekiq_options["retry"]).to eq 1 # ScheduledJob defaults to false
  end

  describe "perform" do
    let(:instance) { described_class.new }
    let(:time) { Time.current - 2.days }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images) }
    let(:bike) { stolen_record.bike }
    let!(:image_attachment) { stolen_record.reload.image_four_by_five.attachment }

    it "does not enqueue anything, but removes orphans" do
      Sidekiq::Job.clear_all
      instance.perform
      expect(described_class.jobs.map { |j| j["args"] }.last&.flatten).to be_blank
    end

    context "with image created over 1 day ago" do
      before { image_attachment.update(created_at: time) }

      it "enqueues" do
        Sidekiq::Job.clear_all
        instance.perform
        expect(described_class.jobs.map { |j| j["args"] }.last&.flatten).to eq([stolen_record.id])
      end
    end

    context "bike recovered" do
      before { stolen_record.update(recovered_at: time) }

      it "enqueues" do
        Sidekiq::Job.clear_all
        instance.perform
        expect(described_class.jobs.map { |j| j["args"] }.last&.flatten).to eq([stolen_record.id])
      end
    end

    context "stolen_record deleted" do
      let(:bike2) { FactoryBot.create(:bike) }
      before do
        bike.update(deleted_at: time)
        bike2.update(deleted_at: time)
      end

      it "enqueues" do
        expect(Bike.count).to eq 0
        Sidekiq::Job.clear_all
        instance.perform
        expect(described_class.jobs.map { |j| j["args"] }.last&.flatten).to eq([stolen_record.id])
      end
    end

    context "passed an ID" do
      let(:stolen_record) { FactoryBot.create(:stolen_record) }
      let!(:alert_image) { FactoryBot.create(:alert_image, stolen_record:) }
      let!(:public_image) { FactoryBot.create(:public_image, :with_image_file, imageable: bike) }
      before do
        ImageServices::StolenProcessor.update_alert_images(stolen_record)
        stolen_record.reload.image_four_by_five.blob.update(created_at: time)
        stolen_record.image_opengraph.blob.update(created_at: time)
        # Don't update square - just to test that things that are created more recently aren't destroyed
      end

      it "does not delete current image, deletes orphaned attachments and alert_image" do
        expect(ActiveStorage::Blob.count).to eq 3
        ImageServices::StolenProcessor.update_alert_images(stolen_record, force_regenerate: true)
        expect(ActiveStorage::Blob.count).to eq 6
        # I'd really prefer if this didn't actually delete the records, but...
        expect(ActiveStorage::Attachment.count).to eq 3
        expect(AlertImage.count).to eq 1
        instance.perform
        instance.perform(stolen_record.id)

        # Because square wasn't created before the check period
        expect(ActiveStorage::Blob.count).to eq 4
        expect(ActiveStorage::Attachment.count).to eq 3
        expect(AlertImage.count).to eq 0
        expect(stolen_record.reload.images_attached?).to be_truthy
      end

      context "storage fails while deleting the file" do
        # Stubbed because the real trigger is a transient S3 5xx, which can't be provoked
        before do
          allow_any_instance_of(ActiveStorage::Service::DiskService).to receive(:delete)
            .and_raise(StandardError, "We encountered an internal error. Please try again.")
        end

        it "keeps the blob, so the file isn't orphaned and the next run retries" do
          ImageServices::StolenProcessor.update_alert_images(stolen_record, force_regenerate: true)
          expect(ActiveStorage::Blob.count).to eq 6

          expect { instance.perform(stolen_record.id) }.to raise_error(/internal error/)

          expect(ActiveStorage::Blob.count).to eq 6
          expect(stolen_record.reload.images_attached?).to be_truthy
        end
      end
    end

    context "blob stamped for the stolen_record, but not named for it" do
      let!(:stamped_blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("photo"), filename: "alert.jpeg",
          content_type: "image/jpeg")
          .tap { it.update_columns(created_at: time, binx_data: {"stolen_record_id" => stolen_record.id}) }
      end

      it "purges it, rather than leaving it for a reaper that skips the stamp" do
        expect(stolen_record.reload.images_attached?).to be_truthy

        instance.perform(stolen_record.id)

        expect(ActiveStorage::Blob.where(id: stamped_blob.id)).to be_empty
        expect(stolen_record.reload.images_attached?).to be_truthy
      end
    end

    context "images removed, with the attachments still present" do
      let(:stolen_record) { FactoryBot.create(:stolen_record) }
      let!(:public_image) { FactoryBot.create(:public_image, :with_image_file, imageable: bike) }
      before do
        ImageServices::StolenProcessor.update_alert_images(stolen_record)
        ActiveStorage::Blob.update_all(created_at: time)
        public_image.destroy
        # Marks the images removed, leaving the attachments in place
        ImageServices::StolenProcessor.update_alert_images(stolen_record.reload)
      end

      it "purges the blobs instead of stranding them behind the deleted attachments" do
        expect(stolen_record.reload.images_attached?).to be_falsey
        expect(ActiveStorage::Blob.count).to eq 3
        expect(ActiveStorage::Attachment.count).to eq 3

        instance.perform(stolen_record.id)

        expect(ActiveStorage::Attachment.count).to eq 0
        expect(ActiveStorage::Blob.count).to eq 0
      end
    end
  end
end
