class AddImageToBParams < ActiveRecord::Migration
  def change
    add_column :bikeParams, :image, :string
    add_column :bikeParams, :image_tmp, :string
  end
end
