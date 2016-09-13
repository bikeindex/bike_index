class AddPosAndNewToCreationState < ActiveRecord::Migration
  def change
    change_column :creation_states, :is_bulk, :boolean, default: false, null: false
    add_column :creation_states, :is_pos, :boolean, default: false, null: false
    add_column :creation_states, :is_new, :boolean, default: false, null: false
  end
end
