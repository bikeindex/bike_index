RSpec.shared_context :scheduled_job do
  def clear_scheduled_history
    RedisPool.conn { |r| r.del(ScheduledJobRunner::HISTORY_KEY) }
    Sidekiq.redis { |r| r.del(described_class.redis_queue) }
  end

  before { Sidekiq::Job.clear_all }

  shared_examples_for :scheduled_job_tests do
    describe "scheduling" do
      it "does not need to run immediately after running" do
        clear_scheduled_history
        expect(described_class.should_enqueue?).to be_truthy
        described_class.new.perform
        expect(described_class.should_enqueue?).to be_falsey
      end
    end

    describe "runnering" do
      it "is specified in the runner" do
        expect(ScheduledJobRunner.scheduled_jobs).to include(described_class)
      end
    end
  end
end
