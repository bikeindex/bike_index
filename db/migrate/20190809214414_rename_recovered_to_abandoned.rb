class RenameRecoveredToAbandoned < ActiveRecord::Migration
  def change
    rename_column :bikes, :recovered, :abandoned
  end
end
