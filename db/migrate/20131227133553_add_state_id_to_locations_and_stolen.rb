class AddStateIdToLocationsAndStolen < ActiveRecord::Migration
  def change
    add_column :locations, :us_state_id, :integer
    add_column :stolen_record, :us_state_id, :integer
  end
end
