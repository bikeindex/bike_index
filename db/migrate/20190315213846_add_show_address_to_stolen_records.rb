class AddShowAddressToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :show_address, :boolean, default: false
  end
end
