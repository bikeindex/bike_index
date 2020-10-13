class AddTokenToOwnerships < ActiveRecord::Migration[5.2]
  def change
    add_column :ownerships, :token, :text
  end
end
