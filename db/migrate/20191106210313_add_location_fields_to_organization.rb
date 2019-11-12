class AddLocationFieldsToOrganization < ActiveRecord::Migration
  def change
    change_table :organizations do |t|
      # geocoding for regional organization associations
      t.integer :search_radius, null: false, default: 50
      t.float :location_latitude
      t.float :location_longitude
    end

    add_index :organizations, [:location_latitude, :location_longitude]
  end
end
