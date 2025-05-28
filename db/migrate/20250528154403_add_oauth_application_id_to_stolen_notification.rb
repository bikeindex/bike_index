class AddOauthApplicationIdToStolenNotification < ActiveRecord::Migration[8.0]
  def change
    add_reference :stolen_notifications, :doorkeeper_application, index: true
  end
end
