class RenameIsShopOnOrganizations < ActiveRecord::Migration
  def up
    rename_column :organizations, :is_a_bike_shop, :show_on_map
  end

  def down
    rename_column :organizations, :show_on_map, :is_a_bike_shop
  end
end
