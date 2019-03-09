class AddsFrameMaterialToBikes < ActiveRecord::Migration

  def up
    add_column :bikes, :frame_material, :integer

    # bulk update enum before type cast - one statement per frame material
    defined?(Deprecated::FrameMaterial) && Deprecated::FrameMaterial.find_each do |fm|
      Bike.where(frame_material_id: fm.id).update_all(frame_material: Bike.frame_materials[fm.slug])
    end
  end

  def down
    remove_column :bikes, :frame_material
  end
end
