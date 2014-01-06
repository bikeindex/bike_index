class CreateColorShades < ActiveRecord::Migration
  def change
    create_table :color_shades do |t|
      t.string :name
      t.integer :color_id

      t.timestamps
    end
  end
end
