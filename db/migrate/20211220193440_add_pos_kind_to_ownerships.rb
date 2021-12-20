class AddPosKindToOwnerships < ActiveRecord::Migration[5.2]
  def change
    add_column :ownerships, :pos_kind, :integer
  end
end
