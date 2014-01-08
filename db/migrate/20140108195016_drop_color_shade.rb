class DropColorShade < ActiveRecord::Migration
  def up
    drop_table :color_shades
  end

  def down
    create_table :color_shades do |t|
      t.string :name
      t.integer :color_id

      t.timestamps
    end
  end
end
