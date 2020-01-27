class AddPosKindToCreationDescriptions < ActiveRecord::Migration[4.2]
  def change
    add_column :creation_states, :pos_kind, :integer, default: 0
  end
end
