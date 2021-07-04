class AddFacebookDataToTheftAlerts < ActiveRecord::Migration[5.2]
  def change
    add_column :theft_alert_plans, :amount_cents_facebook, :integer
    add_column :theft_alerts, :facebook_data, :jsonb
  end
end
