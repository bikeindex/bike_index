class RemoveFacebookPostUrlFromTheftAlerts < ActiveRecord::Migration[5.2]
  def change
    remove_column :theft_alerts, :facebook_post_url, :text
  end
end
