class RemoveFrameMaterialOtherFromBikes < ActiveRecord::Migration
  def up
    remove_column :bikes, :frame_material_other
  end

  def down
    add_column :bikes, :frame_material_other, :string
  end
end
