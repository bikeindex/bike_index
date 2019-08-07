class RenameRecoveredToAbandonded < ActiveRecord::Migration

  def up
    rename_column :bikes, :recovered, :abandoned
  end

  def down
    rename_column :bikes, :abandoned, :recovered
  end
end
