class RenameRecoveredToAbandoned < ActiveRecord::Migration[4.2]
  def change
    rename_column :bikes, :recovered, :abandoned
  end
end
