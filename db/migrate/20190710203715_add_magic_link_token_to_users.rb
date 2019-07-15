class AddMagicLinkTokenToUsers < ActiveRecord::Migration
  def change
    add_column :users, :magic_link_token, :text
  end
end
