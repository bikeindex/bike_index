class AddPriorityToWheelSizeAndColor < ActiveRecord::Migration
  def change
    add_column :wheel_sizes, :priority, :integer
    add_column :colors, :priority, :integer
  end
end
