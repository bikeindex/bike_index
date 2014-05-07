class AddMoreColorIdsToPaints < ActiveRecord::Migration
  def change
    add_column :paints, :secondary_color_id, :integer
    add_column :paints, :tertiary_color_id, :integer
  end
end
