class AddCountryToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :country_id, :integer
  end
end
