class AddDescriptionToBlogs < ActiveRecord::Migration
  def change
    add_column :blogs, :description_abbr, :text
  end
end
