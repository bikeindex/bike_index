class AddTheftAlertPlans < ActiveRecord::Migration
  def change
    create_table :theft_alert_plans do |t|
      t.string :name, null: false, default: ""
      t.integer :amount_cents, null: false
      t.integer :views, null: false
      t.integer :duration_days, null: false
      t.string :description, null: false, default: ""
      t.boolean :active, null: false, default: true

      t.timestamps null: false
    end
  end
end
