class RemoveNewBikeNotificationFromOrganizations < ActiveRecord::Migration[4.2]
  def change
    remove_column :organizations, :new_bike_notification, :text
  end
end
