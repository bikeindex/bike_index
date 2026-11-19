require "rails_helper"

RSpec.describe ApplicationJob, type: :job do
  describe "with_redlock" do
    let(:job_class) { ProcessParkingNotificationJob }
    let(:instance) { job_class.new }

    it "runs once per id at a time, and unlocks after an error" do
      expect(instance.with_redlock(12) { job_class.locked_for?(12) }).to be_truthy
      expect(job_class.locked_for?(12)).to be_falsey

      lock_manager = job_class.new_lock_manager
      redlock = lock_manager.lock(job_class.redlock_key(12), 5000)
      expect(instance.with_redlock(12) { fail "shouldn't run" }).to eq false
      lock_manager.unlock(redlock)

      expect { instance.with_redlock(12) { fail "boom" } }.to raise_error("boom")
      expect(job_class.locked_for?(12)).to be_falsey
    end
  end
end
