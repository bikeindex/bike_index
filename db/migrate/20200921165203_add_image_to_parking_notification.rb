class AddImageToParkingNotification < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :image, :text
    add_column :parking_notifications, :image_processing, :boolean, null: false, default: false
  end
end
