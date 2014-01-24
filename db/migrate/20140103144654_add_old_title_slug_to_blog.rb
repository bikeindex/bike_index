class AddOldTitleSlugToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :old_title_slug, :string
  end
end
