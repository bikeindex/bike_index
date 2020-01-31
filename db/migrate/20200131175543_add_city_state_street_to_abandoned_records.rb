class AddCityStateStreetToAbandonedRecords < ActiveRecord::Migration[5.2]
  def change
    add_column :abandoned_records, :zipcode, :string
    add_column :abandoned_records, :city, :string
    add_column :abandoned_records, :neighborhood, :string
    add_column :abandoned_records, :hide_address, :boolean, default: false

    add_reference :abandoned_records, :country, index: true
    add_reference :abandoned_records, :state, index: true

    rename_column :abandoned_records, :address, :street
  end
end
