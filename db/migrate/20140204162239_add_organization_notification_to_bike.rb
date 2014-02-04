class AddOrganizationNotificationToBike < ActiveRecord::Migration
  def change
    add_column :organizations, :new_bike_notification, :text
  end
end
