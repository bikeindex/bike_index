class StoreSerialInLoggedSearches < ActiveRecord::Migration[6.1]
  def change
    add_column :logged_searches, :serial_normalized, :string
  end
end
