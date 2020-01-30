class AddMagicLinkTokenToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :magic_link_token, :text
  end
end
