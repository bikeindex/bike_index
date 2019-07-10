class AddMagicLinkTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :magic_link_token, :text
    add_column :users, :last_login_ip, :string
  end
end
