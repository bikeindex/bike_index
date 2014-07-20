class AddDescriptionCacheToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :all_description, :text
  end
end
