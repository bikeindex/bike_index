class RemoveFrameMaterialIdFromBikes < ActiveRecord::Migration[4.2]
  def change
    remove_reference :bikes, :frame_material
  end
end
