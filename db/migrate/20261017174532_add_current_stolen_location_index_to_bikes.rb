class AddCurrentStolenLocationIndexToBikes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # status 1 and 3 are status_stolen and status_impounded — the proximity search count
  def change
    add_index :bikes, %i[latitude longitude],
      where: "status IN (1, 3) AND example = false AND user_hidden = false AND likely_spam = false AND deleted_at IS NULL",
      name: :index_bikes_current_stolen_or_impounded_on_location,
      algorithm: :concurrently, if_not_exists: true
  end
end
