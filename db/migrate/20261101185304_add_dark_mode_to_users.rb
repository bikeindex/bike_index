class AddDarkModeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dark_mode, :integer, default: 0, null: false
  end
end
