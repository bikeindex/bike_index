class AddPasswordlessUserToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :passwordless_user, :boolean, default: false, null: false
  end
end
