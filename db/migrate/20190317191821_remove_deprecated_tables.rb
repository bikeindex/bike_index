class RemoveDeprecatedTables < ActiveRecord::Migration
  def change
    drop_table :frame_materials
    drop_table :handlebar_types
    drop_table :propulsion_types
    drop_table :cycle_types
    remove_reference :bikes, :cycle_type
    remove_reference :bikes, :handlebar_type
    remove_reference :bikes, :propulsion_type
  end
end
