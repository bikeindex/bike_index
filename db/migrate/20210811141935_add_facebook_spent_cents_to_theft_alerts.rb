class AddFacebookSpentCentsToTheftAlerts < ActiveRecord::Migration[5.2]
  def change
    add_column :theft_alerts, :amount_cents_facebook_spent, :integer
  end
end
