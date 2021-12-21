class AddPosKindToOwnerships < ActiveRecord::Migration[5.2]
  def change
    add_column :ownerships, :pos_kind, :integer
    add_column :ownerships, :is_new, :boolean, default: false
  end
end
