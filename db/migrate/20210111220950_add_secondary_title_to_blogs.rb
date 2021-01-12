class AddSecondaryTitleToBlogs < ActiveRecord::Migration[5.2]
  def change
    add_column :blogs, :secondary_title, :text
    add_column :blogs, :kind, :integer, default: 0
  end
end
