# == Schema Information
#
# Table name: ambassador_tasks
#
#  id          :integer          not null, primary key
#  description :string           default(""), not null
#  title       :string           default(""), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_ambassador_tasks_on_title  (title) UNIQUE
#
require "rails_helper"

RSpec.describe AmbassadorTask, type: :model do
  describe "#ensure_assigned_to_all_ambassadors!" do
    it "propogates assignments to the new task on creation" do
      ambassador = FactoryBot.create(:ambassador)
      expect(AmbassadorTaskAssignment.count).to eq(0)

      task = AmbassadorTask.create(title: "New Task")
      Sidekiq::Job.drain_all

      expect(AmbassadorTaskAssignment.count).to eq(1)
      expect(ambassador.ambassador_tasks.pluck(:id)).to match_array([task.id])
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
