class AddCountryToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :country_id, :integer
  end
end
