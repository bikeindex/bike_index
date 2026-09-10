class AddPartnerShopToMarketplaceOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :marketplace_orders, :marketplace_partner_shop
  end
end
