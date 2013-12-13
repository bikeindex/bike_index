class RemoveSubtitleFromBlogsBecauseItsDumb < ActiveRecord::Migration
  def up
    remove_column :blogs, :subtitle
  end

  def down
    add_column :blogs, :subtitle, :text
  end
end