class AddListingOrderToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :listing_order, :integer
  end
end
