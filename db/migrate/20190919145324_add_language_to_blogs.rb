class AddLanguageToBlogs < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :language, :integer, default: 0, null: false
  end
end
