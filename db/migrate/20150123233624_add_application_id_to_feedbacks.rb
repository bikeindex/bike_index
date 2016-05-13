class AddApplicationIdToFeedbacks < ActiveRecord::Migration
  def change
    add_column :stolenNotifications, :oauth_application_id, :integer
    add_column :oauth_applications, :can_send_stolenNotifications, :boolean, default: false, null: false
    add_index :stolenNotifications, :oauth_application_id
  end
end
