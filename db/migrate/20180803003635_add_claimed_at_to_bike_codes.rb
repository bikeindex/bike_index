class AddClaimedAtToBikeCodes < ActiveRecord::Migration
  def change
    add_column :bike_codes, :claimed_at, :datetime
  end
end
