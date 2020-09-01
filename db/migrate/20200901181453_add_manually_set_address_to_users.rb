class AddManuallySetAddressToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :manually_set_address, :boolean, default: false
  end
end
