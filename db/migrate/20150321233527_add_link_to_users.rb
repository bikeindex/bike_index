class AddLinkToUsers < ActiveRecord::Migration
  def change
    add_column :users, :my_bikes_hash, :text
  end
end
