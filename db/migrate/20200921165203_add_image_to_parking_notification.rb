class AddImageToParkingNotification < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :image, :text
  end
end
