class RemoveNameFromAds < ActiveRecord::Migration
  def up
    remove_column :ads, :name
  end

  def down
    add_column :ads, :name, :string
  end
end
