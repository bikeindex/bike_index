class RemoveFrameMaterialIdFromBikes < ActiveRecord::Migration
  def change
    remove_reference :bikes, :frame_material
  end
end
