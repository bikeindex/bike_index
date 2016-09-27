class ChangeUserConfirmedToBeDefaultFalse < ActiveRecord::Migration
  def change
    change_column :users, :confirmed, :boolean, default: false, null: false
  end
end
