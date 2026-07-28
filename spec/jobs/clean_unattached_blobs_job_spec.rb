require "rails_helper"

RSpec.describe CleanUnattachedBlobsJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:stale) { Time.current - 31.days }

  def create_blob(created_at:, filename: "bike.jpg")
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("photo"), filename:,
      content_type: "image/jpeg").tap { it.update_column(:created_at, created_at) }
  end

  it "runs about daily" do
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let!(:attached) { FactoryBot.create(:public_image, :with_attached_file).file.blob }
    let!(:orphan) { create_blob(created_at: stale) }
    let!(:recent_orphan) { create_blob(created_at: Time.current - 29.days) }
    # BikeJobs::RemoveOrphanedImagesJob owns these - a superseded one stays unattached on purpose
    let!(:alert_image) { create_blob(created_at: stale, filename: "stolen-42-opengraph.jpeg") }

    it "purges only the aged blobs nothing references anymore" do
      attached.update_column(:created_at, stale)
      expect(described_class.new.blobs.pluck(:id)).to eq([orphan.id])

      Sidekiq::Testing.inline! { described_class.new.perform }
      expect(ActiveStorage::Blob.pluck(:id))
        .to match_array([attached.id, recent_orphan.id, alert_image.id])
    end
  end
end
