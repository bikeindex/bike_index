class AddPosKindToCreationDescriptions < ActiveRecord::Migration
  def change
    add_column :creation_states, :pos_kind, :integer, default: 0
  end
end
