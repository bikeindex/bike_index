require "rails_helper"

RSpec.describe ScheduledJobRunner, type: :lib do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "has scheduled_jobs in order" do
    scheduled_jobs = described_class.scheduled_jobs.map(&:to_s) - [described_class.name.to_s]

    expect(scheduled_jobs).to eq scheduled_jobs.sort
  end

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "high_priority" # overrides default
    expect(described_class.frequency).to be >= 15
  end

  it "has correct scheduled workers" do
    expect(described_class.scheduled_jobs.count).to be > 5
  end

  describe "skip_scheduling?" do
    let(:instance) { described_class.new }

    it "is false by default" do
      expect(instance.skip_scheduling?).to be_falsey
    end

    context "when SIDEKIQ_SKIP_SCHEDULED_JOB_RUNNER is set" do
      before { stub_const("ENV", ENV.to_hash.merge("SIDEKIQ_SKIP_SCHEDULED_JOB_RUNNER" => "true")) }

      it "is true, and perform does not enqueue workers or record history" do
        clear_scheduled_history
        Sidekiq::Job.clear_all
        expect(instance.skip_scheduling?).to be_truthy
        instance.perform
        expect(described_class.last_started).to be_blank
        described_class.scheduled_non_scheduler_workers.each do |worker|
          expect(worker.jobs.count).to eq 0
        end
      end
    end
  end

  describe "perform" do
    it "schedules all the workers" do
      clear_scheduled_history
      Sidekiq::Job.clear_all
      expect(described_class.scheduled_jobs.count).to be > 0
      # Get all the possible queues for scheduled jobs, and remove their history
      redis_queues = described_class.scheduled_jobs.map(&:redis_queue).uniq
      Sidekiq.redis { |r| redis_queues.each { r.del(it) } }
      # Sanity check it
      expect(CleanBParamsJob.should_enqueue?).to be_truthy

      described_class.new.perform
      described_class.scheduled_non_scheduler_workers.each do |worker|
        expect(worker.jobs.count).to eq 1
      end
    end
  end

  describe "bin/run_scheduler" do
    # The review-app cron runs this script instead of `rake run_scheduler` to skip
    # booting Rails. It enqueues described_class via the Sidekiq client, so it must
    # stay equivalent to perform_async and honor the enqueued? dedup guard.
    let(:queue) { Sidekiq::Queue.new("high_priority") }
    let(:comparable) { ->(job) { job.item.slice("class", "queue", "retry", "args") } }

    def run_scheduler!
      silence_warnings { load Rails.root.join("bin", "run_scheduler").to_s }
    end

    around { |example| Sidekiq::Testing.disable! { example.run } }
    before { Sidekiq.redis { |r| r.del("queue:high_priority") } }
    after { Sidekiq.redis { |r| r.del("queue:high_priority") } }

    it "enqueues described_class, matching perform_async" do
      run_scheduler!

      expect(queue.size).to eq 1
      enqueued = queue.first
      expect(enqueued.klass).to eq described_class.name
      expect(comparable.call(enqueued))
        .to eq("class" => described_class.name, "queue" => "high_priority", "retry" => false, "args" => [])

      described_class.perform_async
      expect(comparable.call(queue.to_a.last)).to eq comparable.call(enqueued)
    end

    it "does not enqueue when one is already queued" do
      described_class.perform_async
      expect(described_class.should_enqueue?).to be_falsey

      run_scheduler!
      expect(queue.size).to eq 1
    end
  end

  describe "staggered scheduling" do
    it "fails if 3 things are scheduled the same frequency" do
      frequencies = described_class.scheduled_jobs
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
