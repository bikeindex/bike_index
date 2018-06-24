class MakeCreationStateEnum < ActiveRecord::Migration
  def change
    rename_column :creation_states, :origin, :origin_string
    add_column :creation_states, :origin, :integer
  end
end
