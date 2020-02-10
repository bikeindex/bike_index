class RenameBikeStateToStatus < ActiveRecord::Migration[5.2]
  def change
    rename_column :bikes, :state, :status
    rename_column :creation_states, :state, :status
  end
end
