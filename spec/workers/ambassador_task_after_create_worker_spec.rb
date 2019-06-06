require "spec_helper"

describe AmbassadorTaskAfterCreateWorker do
  describe "#perform" do
    it "assigns the given task to all ambassadors" do
      task_id = 1
      allow(AmbassadorTaskAssignmentCreator)
        .to(receive(:assign_task_to_all_ambassadors).with(task_id))

      described_class.new.perform(task_id)

      expect(AmbassadorTaskAssignmentCreator)
        .to(have_received(:assign_task_to_all_ambassadors).once)
    end
  end
end
