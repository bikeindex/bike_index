class AddGraduatedNotificationIntervalToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :graduated_notification_interval, :bigint
  end
end
