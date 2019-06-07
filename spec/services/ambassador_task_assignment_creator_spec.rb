require "spec_helper"

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

        AmbassadorTaskAssignmentCreator.assign_task_to_all_ambassadors(task.id)

        expect(AmbassadorTaskAssignment.count).to eq(3)
        expect(user.ambassador_task_assignments.count).to eq(0)
        expect(a1.ambassador_task_assignments.count).to eq(1)
        expect(a2.ambassador_task_assignments.count).to eq(1)
        expect(a3.ambassador_task_assignments.count).to eq(1)
      end
    end

    context "given anything other than an AmbassadorTask or AmbassadorTask id" do
      it "raises ArgumentError" do
        invocation = -> {
          AmbassadorTaskAssignmentCreator.assign_task_to_all_ambassadors({})
        }
        expect { invocation.call }.to raise_error(ArgumentError)
      end
    end

    it "raises ActiveRecord::RecordNotFound" do
      invocation = -> {
        AmbassadorTaskAssignmentCreator.assign_task_to_all_ambassadors(99)
      }
      expect { invocation.call }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".assign_all_ambassador_tasks_to" do
    context "given an Ambassador or Ambassador id" do
      it "idempotently creates all assignments for the given ambassador" do
        task_ids = FactoryBot.create_list(:ambassador_task, 3).map(&:id)
        ambassador = FactoryBot.create(:ambassador)

        AmbassadorTaskAssignmentCreator.assign_all_ambassador_tasks_to(ambassador)

        found_task_ids = ambassador.ambassador_task_assignments.pluck(:ambassador_task_id)
        expect(found_task_ids).to match_array(task_ids)

        AmbassadorTaskAssignmentCreator.assign_all_ambassador_tasks_to(ambassador.id)

        found_task_ids = ambassador.ambassador_task_assignments.pluck(:ambassador_task_id)
        expect(found_task_ids).to match_array(task_ids)
      end
    end

    context "given an Ambassador that can't be found" do
      it "raises ActiveRecord::RecordNotFound" do
        invocation = -> {
          AmbassadorTaskAssignmentCreator.assign_all_ambassador_tasks_to(99)
        }
        expect { invocation.call }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "given anything other than an Ambassador or Ambassador id" do
      it "raises ArgumentError" do
        invocation = -> {
          AmbassadorTaskAssignmentCreator.assign_all_ambassador_tasks_to({})
        }
        expect { invocation.call }.to raise_error(ArgumentError)
      end
    end
  end
end
