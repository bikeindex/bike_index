class AddLanguageToBlogs < ActiveRecord::Migration
  def change
    add_column :blogs, :language, :integer, default: 0, null: false
  end
end
