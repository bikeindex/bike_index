class RemoveNewBikeNotificationFromOrganizations < ActiveRecord::Migration
  def change
    remove_column :organizations, :new_bike_notification, :text
  end
end
