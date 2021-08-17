class AddNoAddressToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :no_address, :boolean, default: false
  end
end
