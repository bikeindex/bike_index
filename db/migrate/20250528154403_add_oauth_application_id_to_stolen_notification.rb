class AddOauthApplicationIdToStolenNotification < ActiveRecord::Migration[8.0]
  def change
    add_reference :stolen_notifications, :doorkeeper_app, index: true
    add_reference :mail_snippets, :doorkeeper_app, index: true
  end
end
