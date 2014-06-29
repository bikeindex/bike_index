class AddDisplayToColor < ActiveRecord::Migration
  def change
    add_column :colors, :display, :string
  end
end
