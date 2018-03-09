class UpdateUserBanning < ActiveRecord::Migration
  def change
    change_column :users, :banned, :boolean, default: false, null: false
  end
end
