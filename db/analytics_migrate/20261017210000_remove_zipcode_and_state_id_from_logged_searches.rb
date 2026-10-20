class RemoveZipcodeAndStateIdFromLoggedSearches < ActiveRecord::Migration[8.1]
  def change
    remove_index :logged_searches, :state_id
    change_table :logged_searches, bulk: true do |t|
      t.remove :zipcode, type: :string
      t.remove :state_id, type: :bigint
    end
  end
end
