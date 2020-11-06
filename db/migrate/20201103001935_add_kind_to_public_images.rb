class AddKindToPublicImages < ActiveRecord::Migration[5.2]
  def change
    add_column :public_images, :kind, :integer, default: 0
  end
end
