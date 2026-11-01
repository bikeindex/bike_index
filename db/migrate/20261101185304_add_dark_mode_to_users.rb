class AddDarkModeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dark_mode, :boolean, default: false, null: false
  end
end
