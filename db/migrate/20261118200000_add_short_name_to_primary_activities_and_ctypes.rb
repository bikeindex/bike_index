class AddShortNameToPrimaryActivitiesAndCtypes < ActiveRecord::Migration[8.1]
  def change
    add_column :primary_activities, :short_name, :string
    add_column :ctypes, :short_name, :string
  end
end
