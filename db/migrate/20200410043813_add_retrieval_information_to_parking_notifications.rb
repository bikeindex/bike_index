class AddRetrievalInformationToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :status, :integer, default: 0
    add_column :parking_notifications, :retrieved_at, :datetime
    add_column :parking_notifications, :retrieved_kind, :integer
    add_column :parking_notifications, :retrieval_link_token, :text
    add_reference :parking_notifications, :retrieved_by, index: true
  end
end
