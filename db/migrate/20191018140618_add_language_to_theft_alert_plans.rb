class AddLanguageToTheftAlertPlans < ActiveRecord::Migration[4.2]
  def change
    add_column :theft_alert_plans, :language, :integer, default: 0, null: false
  end
end
