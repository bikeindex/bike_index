class AddRemoteImageUrlToPublicImages < ActiveRecord::Migration[4.2]
  def change
    add_column :public_images, :external_image_url, :text
  end
end
