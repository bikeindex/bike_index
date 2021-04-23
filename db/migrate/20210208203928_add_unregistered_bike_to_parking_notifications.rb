class AddUnregisteredBikeToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_records, :unregistered_bike, :boolean, default: false
  end
end
