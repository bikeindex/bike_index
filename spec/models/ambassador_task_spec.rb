require "spec_helper"

describe AmbassadorTask, type: :model do
  describe "#ensure_assigned_to_all_ambassadors!" do
    it "idempotently creates assignments to the given task for all ambassadors" do
      user = FactoryBot.create(:user_confirmed)
      a1, a2, a3 = FactoryBot.create_list(:ambassador, 3)
      task = FactoryBot.create(:ambassador_task)

      task.ensure_assigned_to_all_ambassadors!

      expect(user.ambassador_task_assignments.count).to eq(0)
      expect(a1.ambassador_task_assignments.count).to eq(1)
      expect(a2.ambassador_task_assignments.count).to eq(1)
      expect(a3.ambassador_task_assignments.count).to eq(1)

      task.ensure_assigned_to_all_ambassadors!

      expect(user.ambassador_task_assignments.count).to eq(0)
      expect(a1.ambassador_task_assignments.count).to eq(1)
      expect(a2.ambassador_task_assignments.count).to eq(1)
      expect(a3.ambassador_task_assignments.count).to eq(1)
    end
  end

  describe "#assign_to" do
    context "given a non-ambassador" do
      it "does not assign and returns the invalid assignment instance" do
        user = FactoryBot.create(:user_confirmed)
        task = FactoryBot.create(:ambassador_task)

        assignment = task.assign_to(user)

        expect(user.ambassador_task_assignments).to be_empty
        expect(assignment).to_not be_valid
        expect(assignment.errors.full_messages).to_not be_empty
      end
    end

    context "given an ambassador" do
      it "assigns the receiver to the given ambassador" do
        ambassador = FactoryBot.create(:ambassador)
        task = FactoryBot.create(:ambassador_task)

        assignment = task.assign_to(ambassador)

        expect(assignment).to eq(ambassador.ambassador_task_assignments.first)
      end
    end

    context "given a duplicate assignment" do
      it "does not create the assignment" do
        assignment = FactoryBot.create(:ambassador_task_assignment)
        task = assignment.ambassador_task
        ambassador = assignment.user

        dupe_assignment = task.assign_to(ambassador)

        expect(ambassador.ambassador_task_assignments.count).to eq(1)
        expect(dupe_assignment).to_not be_valid
        expect(dupe_assignment.errors[:ambassador_task]).to eq(["has already been taken"])
      end
    end
  end
end
