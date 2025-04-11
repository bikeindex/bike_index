class CreateAddressRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :address_records do |t|
      t.references :country
      t.references :region_record

      t.string :region_string
      t.string :street
      t.string :city
      t.string :neighborhood
      t.string :postal_code

      t.float :latitude
      t.float :longitude

      t.integer :kind
      t.integer :publicly_visible_attribute

      t.timestamps
    end
  end
end
