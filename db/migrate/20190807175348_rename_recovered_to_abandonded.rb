class RenameRecoveredToAbandonded < ActiveRecord::Migration
  def change
    rename_column :bikes, :recovered, :abandoned
  end
end
