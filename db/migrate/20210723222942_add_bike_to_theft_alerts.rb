class AddBikeToTheftAlerts < ActiveRecord::Migration[5.2]
  def change
    add_reference :theft_alerts, :bike, index: true
  end
end
