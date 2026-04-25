class AddPartialIndexForCurrentBikesListingOrder < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :bikes, :listing_order,
      order: {listing_order: :desc},
      where: "example = false AND user_hidden = false AND likely_spam = false AND deleted_at IS NULL",
      name: :index_bikes_current_listing_order,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :bikes, name: :index_bikes_current_listing_order,
      algorithm: :concurrently, if_exists: true
  end
end
