class RemoveDeliveryStatusFromGraduatedNotifications < ActiveRecord::Migration[8.1]
  def change
    remove_column :graduated_notifications, :delivery_status, :string
  end
end
