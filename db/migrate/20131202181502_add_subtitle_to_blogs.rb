class AddSubtitleToBlogs < ActiveRecord::Migration
  def change
    add_column :blogs, :subtitle, :text
  end
end
