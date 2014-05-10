class AddImageToBParams < ActiveRecord::Migration
  def change
    add_column :b_params, :image, :string
    add_column :b_params, :image_tmp, :string
  end
end
