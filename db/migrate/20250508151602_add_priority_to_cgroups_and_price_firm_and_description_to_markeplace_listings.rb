class AddPriorityToCgroupsAndPriceFirmAndDescriptionToMarkeplaceListings < ActiveRecord::Migration[8.0]
  def change
    add_column :cgroups, :priority, :integer, default: 1
    add_column :marketplace_listings, :price_negotiable, :boolean, default: false
    add_column :marketplace_listings, :description, :text
  end
end
