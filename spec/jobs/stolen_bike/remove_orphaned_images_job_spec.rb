require "rails_helper"

RSpec.describe StolenBike::RemoveOrphanedImagesJob, type: :lib do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 20.hours
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
        Images::StolenProcessor.update_alert_images(stolen_record)
        stolen_record.reload.image_four_by_five.blob.update(created_at: time)
        stolen_record.image_landscape.blob.update(created_at: time)
        # Don't update square - just to test that things that are created more recently aren't destroyed
      end

      it "does not delete current image, deletes orphaned attachments and alert_image" do
        expect(ActiveStorage::Blob.count).to eq 3
        Images::StolenProcessor.update_alert_images(stolen_record, force_regenerate: true)
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
    end
  end
end
