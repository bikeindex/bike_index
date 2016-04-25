class AddReferenceUrlToStolenNotifications < ActiveRecord::Migration
  def change
    add_column :stolen_notifications, :reference_url, :string
  end
end
