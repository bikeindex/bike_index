class AddPrivateToPublicImages < ActiveRecord::Migration
  def change
    add_column :public_images, :is_private, :boolean, default: false, null: false
  end
end
