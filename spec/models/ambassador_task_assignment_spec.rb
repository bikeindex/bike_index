require "spec_helper"

describe AmbassadorTaskAssignment, type: :model do
  let(:non_ambassador) { FactoryBot.create(:user) }
  let(:ambassador) { FactoryBot.create(:ambassador) }
  let(:ambassador_task) { FactoryBot.create(:ambassador_task) }

  describe "#completed" do
    it "returns task assignments marked complete within the last 2 hours" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment, :completed_a_day_ago, ambassador: ambassador)
      assignment2 = FactoryBot.create(:ambassador_task_assignment, :completed_an_hour_ago, ambassador: ambassador)
      _assignment3 = FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)

      completed = ambassador.ambassador_task_assignments.completed
      expect(completed).to match_array([assignment1, assignment2])
    end
  end

  describe "#pending_completion" do
    it "returns task assignments marked completed within 2 hours or not at all" do
      _assignment1 = FactoryBot.create(:ambassador_task_assignment, :completed_a_day_ago, ambassador: ambassador)
      assignment2 = FactoryBot.create(:ambassador_task_assignment, :completed_an_hour_ago, ambassador: ambassador)
      assignment3 = FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)

      pending_completion = ambassador.ambassador_task_assignments.pending_completion
      expect(pending_completion).to match_array([assignment2, assignment3])
    end
  end

  describe "#locked_completed" do
    it "returns task assignments marked complete more than 2 hours ago" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment, :completed_a_day_ago, ambassador: ambassador)
      _assignment2 = FactoryBot.create(:ambassador_task_assignment, :completed_an_hour_ago, ambassador: ambassador)
      _assignment3 = FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)

      locked_completed = ambassador.ambassador_task_assignments.locked_completed
      expect(locked_completed).to match_array([assignment1])
    end
  end

  context "validates unqiueness of ambassador scoped to the user" do
    it "is valid if the task assignment is unique per-user" do
      assignment = described_class.new(ambassador: ambassador,
                                       ambassador_task: ambassador_task)
      expect(assignment).to be_valid
    end

    it "is invalid if the task assignment is non-unique per-user" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment)
      ambassador = assignment1.ambassador
      task = assignment1.ambassador_task

      assignment2 = described_class.new(ambassador: ambassador, ambassador_task: task)

      expect(assignment2).to be_invalid
      expect(assignment2.errors[:ambassador_task]).to eq(["has already been taken"])
    end
  end
end
