class AddSecondaryTitleToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :secondary_title, :text
  end
end
