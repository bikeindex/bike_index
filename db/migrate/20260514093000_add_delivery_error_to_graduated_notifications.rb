class AddDeliveryErrorToGraduatedNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :graduated_notifications, :delivery_error, :string
  end
end
