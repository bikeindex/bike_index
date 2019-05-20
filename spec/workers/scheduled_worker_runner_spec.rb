require "spec_helper"

describe ScheduledWorkerRunner, type: :lib do
  let(:subject) { ScheduledWorkerRunner }
  let(:instance) { subject.new }
  let(:scheduled_workers) { [UpdateExpiredInvoiceWorker, UpdateCountsWorker, UpdateOrganizationPosKindWorker] }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority" # overrides default
    expect(subject.frequency).to be > 1.minute
  end

  it "has correct scheduled workers" do
    expect(subject.scheduled_workers).to match_array(scheduled_workers + [subject])
  end

  describe "perform" do
    it "schedules all the workers" do
      clear_scheduled_history
      expect(subject.scheduled_workers.count).to be > 0
      instance.perform
      subject.scheduled_non_scheduler_workers.each do |worker|
        expect(worker.jobs.count).to eq 1
      end
    end
  end
end
