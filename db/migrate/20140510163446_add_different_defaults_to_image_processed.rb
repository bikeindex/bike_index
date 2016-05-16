class AddDifferentDefaultsToImageProcessed < ActiveRecord::Migration
  def up
    change_column :bikeParams, :image_processed, :boolean, default: true, null: true
  end
  def down
    change_column :bikeParams, :image_processed, :boolean, default: false, null: false
  end
end
