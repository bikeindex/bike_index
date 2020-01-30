class AddClaimedAtToBikeCodes < ActiveRecord::Migration[4.2]
  def change
    add_column :bike_codes, :claimed_at, :datetime
  end
end
