class RemoveUnneededIndexes < ActiveRecord::Migration[7.1]
  def change
    remove_index :ambassador_task_assignments, name: "index_ambassador_task_assignments_on_user_id", column: :user_id
  end
end
