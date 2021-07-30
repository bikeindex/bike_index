class AddRegistrationInformationToCreationStates < ActiveRecord::Migration[5.2]
  def change
    add_column :creation_states, :registration_info, :jsonb
    rename_column :bikes, :creation_state_id, :current_creation_state_id
  end
end
