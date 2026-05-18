class AddSellerMemberToMarketplaceListings < ActiveRecord::Migration[8.1]
  def change
    add_column :marketplace_listings, :seller_member, :boolean, default: false, null: false
    add_index :marketplace_listings, :seller_member, where: "seller_member"
  end
end
