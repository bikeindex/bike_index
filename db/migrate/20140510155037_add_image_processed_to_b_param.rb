class AddImageProcessedToBParam < ActiveRecord::Migration
  def change
    add_column :b_params, :image_processed, :boolean, default: false
  end
end
