class AddShowAddressToStolenRecords < ActiveRecord::Migration[4.2]
  def change
    add_column :stolen_records, :show_address, :boolean, default: false
  end
end
