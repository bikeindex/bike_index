class AddStandardToGearTypes < ActiveRecord::Migration
  def change
    add_column :front_gear_types, :standard, :boolean
    add_column :rear_gear_types, :standard, :boolean
  end
end
