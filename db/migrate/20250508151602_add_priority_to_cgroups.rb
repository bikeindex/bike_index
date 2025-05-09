class AddPriorityToCgroups < ActiveRecord::Migration[8.0]
  def change
    add_column :cgroups, :priority, :integer, default: 1
  end
end
