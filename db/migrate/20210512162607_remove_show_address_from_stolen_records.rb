class RemoveShowAddressFromStolenRecords < ActiveRecord::Migration[5.2]
  def change
    remove_column :stolen_records, :show_address, :boolean
  end
end
