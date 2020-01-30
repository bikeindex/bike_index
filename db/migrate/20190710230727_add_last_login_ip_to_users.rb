class AddLastLoginIpToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :last_login_ip, :string
    rename_column :users, :last_login, :last_login_at
  end
end
