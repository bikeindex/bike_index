class AddDefaultFalseToOwnershipClaimed < ActiveRecord::Migration[6.1]
  def change
    change_column :ownerships, :claimed, :boolean, default: false
  end
end
