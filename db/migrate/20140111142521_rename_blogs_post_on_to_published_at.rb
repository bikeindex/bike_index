class RenameBlogsPostOnToPublishedAt < ActiveRecord::Migration
  def up
    rename_column :blogs, :post_date, :published_at
  end

  def down
    rename_column :blogs, :published_at, :post_date
  end
end
