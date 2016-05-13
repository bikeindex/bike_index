class AddImageProcessedToBParam < ActiveRecord::Migration
  def change
    add_column :bikeParams, :image_processed, :boolean, default: false
  end
end
