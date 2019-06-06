require "spec_helper"

describe AmbassadorTask, type: :model do
  describe "#ensure_assigned_to_all_ambassadors!" do
    it "enqueues a job to assign the new task to all ambassadors" do
      task = FactoryBot.create(:ambassador_task)

      expect { task.ensure_assigned_to_all_ambassadors! }
        .to(change { AmbassadorTaskAfterCreateWorker.jobs.size }.by(1))
    end
  end

  describe "#assign_to" do
    it "assigns the receiver to the given ambassador" do
      ambassador = FactoryBot.create(:ambassador)
      task = FactoryBot.create(:ambassador_task)

      assignment = task.assign_to(ambassador)

      expect(assignment).to eq(ambassador.ambassador_task_assignments.first)
    end

    context "given a duplicate assignment" do
      it "does not create the assignment" do
        assignment = FactoryBot.create(:ambassador_task_assignment)
        task = assignment.ambassador_task
        ambassador = assignment.ambassador

        dupe_assignment = task.assign_to(ambassador)

        expect(ambassador.ambassador_task_assignments.count).to eq(1)
        expect(dupe_assignment).to_not be_valid
        expect(dupe_assignment.errors[:ambassador_task]).to eq(["has already been taken"])
      end
    end
  end
end
