class RemoveOldStateFromLocationsAndStolen < ActiveRecord::Migration
  def up
    remove_column :locations, :old_state
    remove_column :stolen_records, :old_state
  end

  def down
    add_column :locations, :old_state, :string
    add_column :stolen_records, :old_state, :string
  end
end
