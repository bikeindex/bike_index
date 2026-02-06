class AddAddressRecordImpoundRecordReference < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :address_records, :impound_record_id, :bigint
    add_index :address_records, :impound_record_id, where: "impound_record_id IS NOT NULL",
      algorithm: :concurrently
  end
end
