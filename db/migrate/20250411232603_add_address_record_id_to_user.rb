class AddAddressRecordIdToUser < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :address_record
  end
end
