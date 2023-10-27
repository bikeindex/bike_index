class StoreSerialInLoggedSearches < ActiveRecord::Migration[6.1]
  def change
    rename_column :logged_searches, :serial, :serial_boolean
    add_column :logged_searches, :serial, :string
  end
end
