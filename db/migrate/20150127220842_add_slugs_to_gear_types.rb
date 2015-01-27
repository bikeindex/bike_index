class AddSlugsToGearTypes < ActiveRecord::Migration
  def change
    add_column :rear_gear_types, :slug, :string
    add_column :front_gear_types, :slug, :string
    add_column :propulsion_types, :slug, :string
  end
end
