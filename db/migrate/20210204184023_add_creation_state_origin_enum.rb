class AddCreationStateOriginEnum < ActiveRecord::Migration[5.2]
  def change
    add_column :creation_states, :origin_enum, :integer
  end
end
