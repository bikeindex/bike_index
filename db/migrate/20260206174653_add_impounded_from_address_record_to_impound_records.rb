class AddImpoundedFromAddressRecordToImpoundRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :impound_records, :impounded_from_address_record_id, :bigint
    add_index :impound_records, :impounded_from_address_record_id,
      where: "impounded_from_address_record_id IS NOT NULL"
  end
end
