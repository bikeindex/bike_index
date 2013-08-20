class RemoveWheelSizeSetFromWheels < ActiveRecord::Migration
  def up
    remove_column :wheel_sizes, :wheel_size_set
  end

  def down
    add_column :wheel_sizes, :wheel_size_set, :string
  end
end
