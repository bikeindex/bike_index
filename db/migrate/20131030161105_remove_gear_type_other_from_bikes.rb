class RemoveGearTypeOtherFromBikes < ActiveRecord::Migration
  def up
    remove_column :bikes, :rear_gear_type_other
    remove_column :bikes, :front_gear_type_other
  end

  def down
    add_column :bikes, :rear_gear_type_other, :string
    add_column :bikes, :front_gear_type_other, :string
  end
end