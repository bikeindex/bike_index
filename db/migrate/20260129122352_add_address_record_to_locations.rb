class AddAddressRecordToLocations < ActiveRecord::Migration[8.0]
  def change
    add_reference :locations, :address_record, index: true
    add_reference :address_records, :organization, index: true
  end
end
