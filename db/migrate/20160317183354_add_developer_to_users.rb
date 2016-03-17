class AddDeveloperToUsers < ActiveRecord::Migration
  def change
    add_column :users, :developer, :boolean, default: false, null: false
  end
end
