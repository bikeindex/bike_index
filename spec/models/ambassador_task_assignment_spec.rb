require "spec_helper"

describe AmbassadorTaskAssignment, type: :model do
  let(:non_ambassador) { FactoryBot.create(:user) }
  let(:ambassador) { FactoryBot.create(:ambassador) }
  let(:ambassador_task) { FactoryBot.create(:ambassador_task) }

  describe "pending_complete" do
    let!(:ambassador_task_assignment1) { FactoryBot.create(:ambassador_task_assignment, user: ambassador, ambassador_task: ambassador_task) }
    let!(:ambassador_task_assignment2) { FactoryBot.create(:ambassador_task_assignment, user: ambassador, completed_at: Time.now - 1.day) }
    it "is complete" do
      ambassador.reload
      expect(ambassador.ambassador_task_assignments.completed).to eq([ambassador_task_assignment2])
      expect(ambassador.ambassador_task_assignments.locked_completed.pluck(:id)).to eq([ambassador_task_assignment2.id])
      expect(ambassador.ambassador_task_assignments.pending_completion.pluck(:id)).to eq([ambassador_task_assignment1.id])
      ambassador_task_assignment1.update_attributes(completed_at: Time.now - 1.minute)
      ambassador.reload
      expect(ambassador.ambassador_task_assignments.pending_completion.pluck(:id)).to eq([ambassador_task_assignment1.id])
    end
  end

  context "validates the associated user is an ambassador" do
    it "is invalid if given a non-ambassador" do
      assignment = described_class.new(user: non_ambassador,
                                       ambassador_task: ambassador_task)
      expect(assignment).to be_invalid
      expect(assignment.errors[:user]).to eq(["must be an ambassador"])
    end

    it "is valid if given an ambassador" do
      assignment = described_class.new(user: ambassador,
                                       ambassador_task: ambassador_task)
      expect(assignment).to be_valid
    end
  end

  context "validates unqiueness of ambassador scoped to the user" do
    it "is valid if the task assignment is unique per-user" do
      assignment = described_class.new(user: ambassador,
                                       ambassador_task: ambassador_task)
      expect(assignment).to be_valid
    end

    it "is invalid if the task assignment is non-unique per-user" do
      assignment1 = FactoryBot.create(:ambassador_task_assignment)
      user = assignment1.user
      task = assignment1.ambassador_task

      assignment2 = described_class.new(user: user, ambassador_task: task)

      expect(assignment2).to be_invalid
      expect(assignment2.errors[:ambassador_task]).to eq(["has already been taken"])
    end
  end
end
