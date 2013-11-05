class AddFramePaintDescriptionToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :frame_paint_description, :string
  end
end
