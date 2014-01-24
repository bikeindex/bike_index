class AddStateIdToLocationsAndStolen < ActiveRecord::Migration
  def change
    add_column :locations, :state_id, :integer
    add_column :stolen_records, :state_id, :integer
  end
end
