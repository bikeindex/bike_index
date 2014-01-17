class RenameHasTwinTypeToHasMultiple < ActiveRecord::Migration
  def up
    rename_column :ctypes, :has_twin_part, :has_multiple
    change_column :ctypes, :has_multiple, :boolean, default: false, null: false
  end

  def down
    rename_column :ctypes, :has_multiple, :has_twin_part
  end
end
