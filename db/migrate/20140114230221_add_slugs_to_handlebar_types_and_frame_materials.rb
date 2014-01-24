class AddSlugsToHandlebarTypesAndFrameMaterials < ActiveRecord::Migration
  def change
    add_column :handlebar_types, :slug, :string
    add_column :frame_materials, :slug, :string
  end
end
