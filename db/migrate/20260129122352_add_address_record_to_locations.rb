class AddAddressRecordToLocations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_reference :locations, :address_record, index: true
    add_reference :address_records, :organization, index: false

    add_index :address_records, :organization_id, where: "organization_id IS NOT NULL", algorithm: :concurrently
  end
end
