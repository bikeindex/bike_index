class AddStandardToGearTypes < ActiveRecord::Migration
  def change
    add_column :front_gear_types, :standard, :boolean, nil: false
    add_column :rear_gear_types, :standard, :boolean, nil: false
  end
end
