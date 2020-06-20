class AddIsInfoToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :is_info, :boolean, default: false
  end
end
