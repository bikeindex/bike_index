shared_context :scheduled_worker do
  let(:redis) { ScheduledWorker.redis }

  def clear_scheduled_history
    ScheduledWorker.redis { |r| r.expire(ScheduledWorkerRunner::HISTORY_KEY, 0) }
  end

  before { Sidekiq::Worker.clear_all }

  shared_examples_for :scheduled_worker_tests do
    describe "scheduling" do
      it "does not need to run immediately after running" do
        clear_scheduled_history
        expect(subject.should_enqueue?).to be_truthy
        instance.perform
        expect(subject.should_enqueue?).to be_falsey
      end
    end
  end
end
