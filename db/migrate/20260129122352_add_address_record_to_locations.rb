disable_ddl_transaction!

class AddAddressRecordToLocations < ActiveRecord::Migration[8.0]
  def change
    add_reference :locations, :address_record, index: false

    add_index :address_records, :organization_id, where: "organization_id IS NOT NULL", algorithm: :concurrently
    remove_index :address_records, :bike_id, algorithm: :concurrently
    remove_index :address_records, :user_id, algorithm: :concurrently
    add_index :address_records, :bike_id, where: "bike_id IS NOT NULL", algorithm: :concurrently
    add_index :address_records, :user_id, where: "user_id IS NOT NULL", algorithm: :concurrently
  end
end
