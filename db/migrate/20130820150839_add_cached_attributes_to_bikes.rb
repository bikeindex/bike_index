class AddCachedAttributesToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :cached_attributes, :text
  end
end
