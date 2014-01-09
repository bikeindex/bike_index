class RemoveFramePaintDescriptionFromBikes < ActiveRecord::Migration
  def up
    remove_column :bikes, :frame_paint_description
  end

  def down
    add_column :bikes, :frame_paint_description, :string
  end
end
