require "rails_helper"

RSpec.describe CleanBulkImportWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let!(:bulk_import1) { FactoryBot.create(:bulk_import_ascend) }
    let!(:bulk_import2) { FactoryBot.create(:bulk_import, created_at: Time.current - 3.days) }
    let!(:bulk_import3) { FactoryBot.create(:bulk_import_ascend, created_at: Time.current - 3.days) }
    it "schedules all the workers" do
      Sidekiq::Worker.clear_all
      expect {
        described_class.new.perform
      }.to change(described_class.jobs, :count).by 1
      expect(described_class.jobs.map { |j| j["args"] }.last.flatten).to eq([bulk_import3.id])
      described_class.drain
      bulk_import1.reload && bulk_import2.reload && bulk_import3.reload
      expect(bulk_import1.file_cleaned).to be_falsey
      expect(bulk_import2.file_cleaned).to be_falsey
      expect(bulk_import3.file_cleaned).to be_truthy
    end
  end
end
