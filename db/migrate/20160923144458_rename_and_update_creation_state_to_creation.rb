class RenameAndUpdateCreationStateToCreation < ActiveRecord::Migration
  def change
    rename_table :creation_states, :creations
    add_reference :bikes, :creation, index: true
    add_reference :creations, :location, index: true
    add_column :creations, :creator_id, :integer
    add_index :bikes, :creator_id
  end
end
