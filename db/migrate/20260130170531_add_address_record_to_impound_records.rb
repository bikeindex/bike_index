class AddAddressRecordToImpoundRecords < ActiveRecord::Migration[8.0]
  def change
    add_reference :impound_records, :address_record, index: true
  end
end
