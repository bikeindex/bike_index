class AddUserHiddenToBikes < ActiveRecord::Migration
  def change
    add_column :ownerships, :user_hidden, :boolean, default: false, null: false
  end
end
