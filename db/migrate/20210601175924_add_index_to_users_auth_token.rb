class AddIndexToUsersAuthToken < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :auth_token
  end
end
