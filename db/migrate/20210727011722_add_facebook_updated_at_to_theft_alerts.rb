class AddFacebookUpdatedAtToTheftAlerts < ActiveRecord::Migration[5.2]
  def change
    add_column :theft_alerts, :facebook_updated_at, :datetime
  end
end
