class AddManuallySetAddressToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :address_set_manually, :boolean, default: false
  end
end
