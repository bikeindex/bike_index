class AddRegionStringAndStreet2ToLoggedSearches < ActiveRecord::Migration[8.1]
  def change
    change_table :logged_searches, bulk: true do |t|
      t.string :region_string
      t.string :street_2
    end
  end
end
