class OnlyIndexAddressRecordUserAndBikeWhenNotNull < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :address_records, :bike_id, algorithm: :concurrently
    remove_index :address_records, :user_id, algorithm: :concurrently
    add_index :address_records, :bike_id, where: "bike_id IS NOT NULL", algorithm: :concurrently
    add_index :address_records, :user_id, where: "user_id IS NOT NULL", algorithm: :concurrently
  end
end
