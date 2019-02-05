class AddListingOrderIndexToBikes < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :bikes, :listing_order, order: { listing_order: :desc }, algorithm: :concurrently
  end
end
