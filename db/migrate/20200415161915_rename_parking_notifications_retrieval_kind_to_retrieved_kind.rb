class RenameParkingNotificationsRetrievalKindToRetrievedKind < ActiveRecord::Migration[5.2]
  def change
    rename_column :parking_notifications, :retrieved_kind, :retrieved_kind
  end
end
