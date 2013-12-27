class RenameStatesToOldStatesForMigration < ActiveRecord::Migration
  def up
    rename_column :locations, :state, :old_state
    rename_column :stolen_records, :state, :old_state
  end

  def down
    rename_column :locations, :old_state, :state
    rename_column :stolen_records, :old_state, :state
  end
end
