class AddStolenSerialMarketplaceMatchIndexToNotifications < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # kind 39 is stolen_serial_marketplace_match
    add_index :notifications, %i[bike_id notifiable_id], unique: true,
      where: "kind = 39 AND notifiable_type = 'Bike'",
      name: :index_notifications_stolen_serial_marketplace_match_unique,
      algorithm: :concurrently
  end
end
