require "rails_helper"

RSpec.describe ScheduledWorkerRunner, type: :lib do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "high_priority" # overrides default
    expect(described_class.frequency).to be > 1.minute
  end

  it "has correct scheduled workers" do
    expect(described_class.scheduled_workers.count).to be > 5
  end

  describe "perform" do
    it "schedules all the workers" do
      clear_scheduled_history
      expect(described_class.scheduled_workers.count).to be > 0
      described_class.new.perform
      described_class.scheduled_non_scheduler_workers.each do |worker|
        expect(worker.jobs.count).to eq 1
      end
    end
  end
end
