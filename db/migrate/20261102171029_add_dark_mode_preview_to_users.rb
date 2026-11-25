class AddDarkModePreviewToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dark_mode_preview, :boolean, default: false, null: false
  end
end
