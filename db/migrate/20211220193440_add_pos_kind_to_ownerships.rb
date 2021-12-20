class AddPosKindToOwnerships < ActiveRecord::Migration[5.2]
  def change
    add_column :ownerships, :kind, :integer
  end
end
