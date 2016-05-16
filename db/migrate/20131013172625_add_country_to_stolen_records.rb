class AddCountryToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :country_id, :integer
  end
end
