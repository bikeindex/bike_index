class ReplaceDarkModePreviewWithColorSchemeOnUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :color_scheme, :integer, default: 2, null: false
    remove_column :users, :dark_mode_preview, :boolean, default: false, null: false
  end
end
