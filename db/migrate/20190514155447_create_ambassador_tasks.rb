class CreateAmbassadorTasks < ActiveRecord::Migration
  def change
    create_table :ambassador_tasks do |t|
      t.string :description, null: false, default: ""

      t.timestamps null: false
    end

    create_table :ambassador_task_assignments do |t|
      t.belongs_to :user, index: true, null: false
      t.belongs_to :ambassador_task, index: true, null: false
      t.datetime :completed_at

      t.timestamps null: false
    end

    add_foreign_key :ambassador_task_assignments, :users, on_delete: :cascade
    add_foreign_key :ambassador_task_assignments, :ambassador_tasks, on_delete: :cascade
  end
end
