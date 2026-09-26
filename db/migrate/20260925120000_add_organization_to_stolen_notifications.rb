class AddOrganizationToStolenNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :stolen_notifications, :organization, index: true
  end
end
