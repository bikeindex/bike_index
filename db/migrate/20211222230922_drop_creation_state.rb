class DropCreationState < ActiveRecord::Migration[5.2]
  def change
    drop_table :creation_states
  end
end
