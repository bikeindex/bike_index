class AddAddressRecordToOwnerships < ActiveRecord::Migration[8.0]
  def change
    add_reference :ownerships, :address_record, index: true
  end
end
