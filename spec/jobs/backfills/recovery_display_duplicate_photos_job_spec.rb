require "rails_helper"

RSpec.describe Backfills::RecoveryDisplayDuplicatePhotosJob, type: :job do
  let(:recovery_display) { FactoryBot.create(:recovery_display, updated_at: 1.week.ago) }

  def attach(record, name)
    ActiveStorage::Attachment.create!(record:, name:,
      blob: ActiveStorage::Blob.create_and_upload!(io: StringIO.new(SecureRandom.hex), filename: "photo.jpg"))
  end

  it "keeps the newest attachment in each slot" do
    photo = attach(recovery_display, "photo")
    duplicate_processed = attach(recovery_display, "photo_processed")
    processed = attach(recovery_display, "photo_processed")
    other_processed = attach(FactoryBot.create(:recovery_display), "photo_processed")
    Sidekiq::Job.clear_all

    described_class.new.perform
    expect(ActiveStorage::Attachment.pluck(:id)).to match_array([photo.id, processed.id, other_processed.id])
    expect(ActiveStorage::Blob.find_by(id: duplicate_processed.blob_id)).to be_nil
    expect(recovery_display.reload.updated_at).to be_within(1.minute).of(Time.current)
    expect(ImageJobs::ProcessRecoveryDisplayPhotoJob.jobs.count).to eq 0
  end
end
