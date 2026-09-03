class RemoveOauthApplicationIdFromStolenNotifications < ActiveRecord::Migration[8.0]
  def change
    remove_column :stolen_notifications, :oauth_application_id, :integer
  end
end
