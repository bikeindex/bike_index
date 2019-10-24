class AddLanguageToTheftAlertPlans < ActiveRecord::Migration
  def change
    add_column :theft_alert_plans, :language, :integer, default: 0, null: false
  end
end
