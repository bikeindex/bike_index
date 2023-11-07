require "rails_helper"

RSpec.describe ScheduledWorkerRunner, type: :lib do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "has scheduled_workers in order" do
    scheduled_workers = described_class.scheduled_workers.map(&:to_s) - [described_class.name.to_s]

    expect(scheduled_workers).to eq scheduled_workers.sort
  end

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

  describe "staggered scheduling" do
    it "fails if 3 things are scheduled the same frequency" do
      frequencies = described_class.scheduled_workers
        .map { |klass| [klass.name, klass.frequency] }.to_h

      # Goofy name to make spec clearer
      too_many_scheduled_jobs_with_same_frequency = frequencies.select do |_name, frequency|
        next if frequency > 23.hours # if they are very infrequent, it's ok
        matches = frequencies.values.select { |v| v == frequency }
        matches.count > 2
      end

      if too_many_scheduled_jobs_with_same_frequency.present?
        pp too_many_scheduled_jobs_with_same_frequency
      end
      expect(too_many_scheduled_jobs_with_same_frequency).to be_blank
    end
  end
end
