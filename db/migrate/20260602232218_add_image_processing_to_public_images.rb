class AddImageProcessingToPublicImages < ActiveRecord::Migration[8.1]
  def change
    add_column :public_images, :image_processing, :boolean, default: false, null: false
  end
end
