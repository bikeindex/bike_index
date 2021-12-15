class RenameTwitterAccountAddressAttr < ActiveRecord::Migration[5.2]
  def change
    rename_column :twitter_accounts, :address, :address_string
  end
end
