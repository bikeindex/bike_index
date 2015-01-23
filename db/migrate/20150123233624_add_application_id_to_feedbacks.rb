class AddApplicationIdToFeedbacks < ActiveRecord::Migration
  def change
    add_column :stolen_notifications, :oauth_application_id, :integer
    add_column :oauth_applications, :can_send_stolen_notifications, :boolean, default: false, null: false
    add_index :stolen_notifications, :oauth_application_id
  end
end
