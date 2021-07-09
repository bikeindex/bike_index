class AddCoordinatesToTheftAlertsAndAdRadiusToPlans < ActiveRecord::Migration[5.2]
  def change
    add_column :theft_alerts, :latitude, :float
    add_column :theft_alerts, :longitude, :float
    add_column :theft_alert_plans, :ad_radius_miles, :integer
  end
end
