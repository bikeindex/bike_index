class AddReferenceUrlToStolenNotifications < ActiveRecord::Migration
  def change
    add_column :stolenNotifications, :reference_url, :string
  end
end
