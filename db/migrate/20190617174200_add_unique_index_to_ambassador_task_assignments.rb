class AddUniqueIndexToAmbassadorTaskAssignments < ActiveRecord::Migration
  def change
    add_index :ambassador_task_assignments,
              [:user_id, :ambassador_task_id],
              unique: true,
              name: "unique_assignment_to_ambassador"
  end
end
