class AddPassThroughStolenNotificationsToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :pass_through_stolen_notifications, :boolean, default: false
  end
end
