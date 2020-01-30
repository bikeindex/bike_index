class AddTitleToAmbassadorTasks < ActiveRecord::Migration[4.2]
  def change
    change_table :ambassador_tasks do |t|
      t.column :title, :string, null: false, default: ""
    end

    add_index :ambassador_tasks, :title, unique: true
  end
end
