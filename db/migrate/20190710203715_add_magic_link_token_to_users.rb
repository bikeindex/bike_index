class AddMagicLinkTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :magic_link_token, :text
    add_column :users, :last_login_ip, :string
    rename_column :users, :last_login, :last_login_at
  end
end
