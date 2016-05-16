class AddStateIdToLocationsAndStolen < ActiveRecord::Migration
  def change
    add_column :locations, :state_id, :integer
    add_column :stolenRecords, :state_id, :integer
  end
end
