class UpdateImageProcessedOnBParams < ActiveRecord::Migration[5.2]
  def change
    change_column :b_params, :image_processed, :boolean, default: false
  end
end
