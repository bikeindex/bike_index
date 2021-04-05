class RemoveBlogTags < ActiveRecord::Migration[5.2]
  def change
    remove_column :blogs, :tags, :text
  end
end
