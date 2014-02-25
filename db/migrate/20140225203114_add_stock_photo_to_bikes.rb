class AddStockPhotoToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :stock_photo_url, :string
  end
end
