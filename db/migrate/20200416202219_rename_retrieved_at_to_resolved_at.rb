class RenameRetrievedAtToResolvedAt < ActiveRecord::Migration[5.2]
  def change
    rename_column :parking_notifications, :retrieved_at, :resolved_at
  end
end
