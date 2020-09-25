class AddClaimedAtToOwnerships < ActiveRecord::Migration[5.2]
  def change
    add_column :ownerships, :claimed_at, :datetime
  end
end
