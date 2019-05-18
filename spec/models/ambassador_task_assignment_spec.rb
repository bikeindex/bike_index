require "spec_helper"

describe AmbassadorTaskAssignment, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:ambassador_task) }
  it { is_expected.to validate_presence_of(:user) }
  it { is_expected.to validate_presence_of(:ambassador_task) }
  it { is_expected.to delegate_method(:description).to(:ambassador_task) }

  let(:non_ambassador) { FactoryBot.create(:user) }
  let(:ambassador) { FactoryBot.create(:ambassador) }
  let(:ambassador_task) { FactoryBot.create(:ambassador_task) }

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
