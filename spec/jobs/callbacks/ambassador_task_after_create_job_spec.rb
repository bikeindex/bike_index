require "rails_helper"

RSpec.describe Callbacks::AmbassadorTaskAfterCreateJob, type: :job do
  describe "#perform" do
    it "assigns the given task to all ambassadors" do
      task = FactoryBot.create(:ambassador_task)
      allow(described_class)
        .to(receive(:assign_task_to_all_ambassadors).with(task))

      described_class.new.perform(task.id)

      expect(described_class)
        .to(have_received(:assign_task_to_all_ambassadors).once)
    end
  end

  describe ".assign_task_to_all_ambassadors" do
    context "given an AmbassadorTask or AmbassadorTask id" do
      it "idempotently creates assignments to the given task for all ambassadors" do
        user = FactoryBot.create(:user_confirmed)
        a1, a2, a3 = FactoryBot.create_list(:ambassador, 3)
        task = FactoryBot.create(:ambassador_task)

        described_class.assign_task_to_all_ambassadors(task)

        expect(AmbassadorTaskAssignment.count).to eq(3)
        expect(user.ambassador_task_assignments.count).to eq(0)
        expect(a1.ambassador_task_assignments.count).to eq(1)
        expect(a2.ambassador_task_assignments.count).to eq(1)
        expect(a3.ambassador_task_assignments.count).to eq(1)

        described_class.assign_task_to_all_ambassadors(task)

        expect(AmbassadorTaskAssignment.count).to eq(3)
        expect(user.ambassador_task_assignments.count).to eq(0)
        expect(a1.ambassador_task_assignments.count).to eq(1)
        expect(a2.ambassador_task_assignments.count).to eq(1)
        expect(a3.ambassador_task_assignments.count).to eq(1)
      end
    end
  end
end
