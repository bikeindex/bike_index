class DropTheftAlerts < ActiveRecord::Migration[8.1]
  def up
    drop_table :theft_alerts
  end

  def down
    create_table :theft_alerts, id: :integer do |t|
      t.integer :stolen_record_id
      t.integer :theft_alert_plan_id
      t.integer :payment_id
      t.integer :user_id
      t.integer :status, default: 0, null: false
      t.datetime :start_at
      t.datetime :end_at
      t.timestamps
      t.text :notes
      t.jsonb :facebook_data
      t.float :latitude
      t.float :longitude
      t.integer :reach
      t.bigint :bike_id
      t.datetime :facebook_updated_at
      t.integer :amount_cents_facebook_spent
      t.boolean :admin, default: false
      t.integer :ad_radius_miles
    end

    add_index :theft_alerts, :bike_id
    add_index :theft_alerts, :payment_id
    add_index :theft_alerts, :stolen_record_id
    add_index :theft_alerts, :theft_alert_plan_id
    add_index :theft_alerts, :user_id

    add_foreign_key :theft_alerts, :payments
    add_foreign_key :theft_alerts, :stolen_records, on_delete: :cascade
    add_foreign_key :theft_alerts, :theft_alert_plans, on_delete: :cascade
    add_foreign_key :theft_alerts, :users
  end
end
