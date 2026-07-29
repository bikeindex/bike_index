require "rails_helper"

RSpec.describe ImageJobs::CleanUnattachedBlobsJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  let(:stale) { Time.current - 31.days }

  def create_blob(created_at:, filename: "bike.jpg", binx_data: nil)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("photo"), filename:,
      content_type: "image/jpeg").tap { it.update_columns(created_at:, binx_data:) }
  end

  it "runs about daily" do
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:stolen_record) { FactoryBot.create(:stolen_record) }
    let!(:attached) { create_blob(created_at: stale).tap { stolen_record.image_square.attach(it) } }
    let!(:orphan) { create_blob(created_at: stale) }
    let!(:recent_orphan) { create_blob(created_at: Time.current - 29.days) }
    # An alert BikeJobs::RemoveOrphanedImagesJob didn't collect - this is the backstop
    let!(:alert_image) do
      create_blob(created_at: stale, filename: "stolen-42-opengraph.jpeg",
        binx_data: {"stolen_record_id" => 42})
    end

    it "purges only the aged blobs nothing references anymore" do
      expect(described_class.new.blobs.map(&:id)).to match_array([orphan.id, alert_image.id])

      Sidekiq::Testing.inline! { described_class.new.perform }
      expect(ActiveStorage::Blob.pluck(:id)).to match_array([attached.id, recent_orphan.id])
    end
  end
end
