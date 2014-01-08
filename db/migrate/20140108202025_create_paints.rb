class CreatePaints < ActiveRecord::Migration
  def change
    create_table :paints do |t|
      t.string :name
      t.integer :color_id
      t.integer :manufacturer_id

      t.timestamps
    end
    add_column :bikes, :paint_id, :integer
  end
end
