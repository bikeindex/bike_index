class AddImageStringLgToBlogs < ActiveRecord::Migration
  def change
    add_column :blogs, :index_image_lg, :string
  end
end
