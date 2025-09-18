class AddAddressRecordToOwnerships < ActiveRecord::Migration[8.0]
  def change
    add_reference :ownerships, :address_record, index: true
    add_reference :bikes, :address_record, index: true
    add_reference :address_records, :bike, index: true
  end
end
