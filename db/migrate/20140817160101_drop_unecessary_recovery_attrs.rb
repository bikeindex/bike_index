class DropUnecessaryRecoveryAttrs < ActiveRecord::Migration
  def up
    remove_column :stolen_records, :recovery_share_approved
    remove_column :stolen_records, :recovery_share_ignore
  end

  def down
    add_column :stolen_records, :recovery_share_approved, :boolean
    add_column :stolen_records, :recovery_share_ignore, :boolean
  end
end
