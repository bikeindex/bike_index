class RemoveSerialFromLoggedSearches < ActiveRecord::Migration[6.1]
  def change
    remove_column :logged_searches, :serial, :boolean
  end
end
