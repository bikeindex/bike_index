class AddImageStringToBlogs < ActiveRecord::Migration
  def change
    add_column :blogs, :index_image, :string
    add_column :blogs, :index_image_id, :integer
  end
end
