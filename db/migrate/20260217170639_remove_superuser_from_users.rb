class RemoveSuperuserFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :superuser, :boolean, default: false, null: false
  end
end
