require "rails_helper"

RSpec.describe AmbassadorTaskAssignmentCreator do
  describe ".assign_task_to_all_ambassadors" do
    context "given an AmbassadorTask or AmbassadorTask id" do
      it "idempotently creates assignments to the given task for all ambassadors" do
        user = FactoryBot.create(:user_confirmed)
        a1, a2, a3 = FactoryBot.create_list(:ambassador, 3)
        task = FactoryBot.create(:ambassador_task)

        AmbassadorTaskAssignmentCreator.assign_task_to_all_ambassadors(task)

        expect(AmbassadorTaskAssignment.count).to eq(3)
        expect(user.ambassador_task_assignments.count).to eq(0)
        expect(a1.ambassador_task_assignments.count).to eq(1)
        expect(a2.ambassador_task_assignments.count).to eq(1)
        expect(a3.ambassador_task_assignments.count).to eq(1)

        AmbassadorTaskAssignmentCreator.assign_task_to_all_ambassadors(task)

        expect(AmbassadorTaskAssignment.count).to eq(3)
        expect(user.ambassador_task_assignments.count).to eq(0)
        expect(a1.ambassador_task_assignments.count).to eq(1)
        expect(a2.ambassador_task_assignments.count).to eq(1)
        expect(a3.ambassador_task_assignments.count).to eq(1)
      end
    end
  end
end
