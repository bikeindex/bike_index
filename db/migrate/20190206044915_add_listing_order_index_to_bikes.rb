class AddListingOrderIndexToBikes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index :bikes, :listing_order, order: { listing_order: :desc }, algorithm: :concurrently
  end
end
