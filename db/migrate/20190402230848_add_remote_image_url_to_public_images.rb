class AddRemoteImageUrlToPublicImages < ActiveRecord::Migration
  def change
    add_column :public_images, :external_image_url, :text
  end
end
