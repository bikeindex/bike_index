class AddKindToStolenNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :stolen_notifications, :kind, :integer
  end
end
