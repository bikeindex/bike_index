require "spec_helper"

describe AmbassadorTask, type: :model do
  it { is_expected.to have_many(:users) }
  it { is_expected.to have_many(:ambassador_task_assignments) }

  it { is_expected.to validate_uniqueness_of(:title) }

  describe "#ensure_assigned_to_all_ambassadors!" do
    it "creates assignments to the given task for all ambassadors" do
      non_ambassador = FactoryBot.create(:user_confirmed)
      a1, a2, a3 = FactoryBot.create_list(:ambassador, 3)
      task = FactoryBot.create(:ambassador_task)
      FactoryBot.create(:ambassador_task_assignment, user: a1, ambassador_task: task)
      expect(non_ambassador.ambassador_task_assignments.count).to eq(0)
      expect(a1.ambassador_task_assignments.count).to eq(1)
      expect(a2.ambassador_task_assignments.count).to eq(0)
      expect(a3.ambassador_task_assignments.count).to eq(0)

      task.ensure_assigned_to_all_ambassadors!
      task.ensure_assigned_to_all_ambassadors!

      expect(non_ambassador.ambassador_task_assignments.count).to eq(0)
      expect(a1.ambassador_task_assignments.count).to eq(1)
      expect(a2.ambassador_task_assignments.count).to eq(1)
      expect(a3.ambassador_task_assignments.count).to eq(1)
    end
  end
end
