class AddDirectUnclaimedNotificationsToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :direct_unclaimed_notifications, :boolean, default: false
  end
end
