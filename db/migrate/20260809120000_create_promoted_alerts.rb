class CreatePromotedAlerts < ActiveRecord::Migration[8.1]
  # Backfills::PromotedAlertJob copies theft_alerts across keeping their ids. Start this
  # sequence above those, so an alert created before the copy runs can't take an id the copy
  # still needs - it would be skipped, and its notifications would end up on whichever alert
  # did take the id. MINVALUE, not setval: pg_dump writes MINVALUE into db/structure.sql, so
  # databases built by db:schema:load get the reservation too, and nothing can wind back under it
  ID_HEADROOM = 10_000

  def up
    # The foreign keys below lock out writes to the tables they reference. Fail rather than
    # queue behind a long transaction and take those writes down with us
    execute("SET LOCAL lock_timeout = '5s'")

    create_table :promoted_alerts do |t|
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

    add_index :promoted_alerts, :bike_id
    add_index :promoted_alerts, :payment_id
    add_index :promoted_alerts, :stolen_record_id
    add_index :promoted_alerts, :theft_alert_plan_id
    add_index :promoted_alerts, :user_id

    add_foreign_key :promoted_alerts, :payments
    add_foreign_key :promoted_alerts, :stolen_records, on_delete: :cascade
    add_foreign_key :promoted_alerts, :theft_alert_plans, on_delete: :cascade
    add_foreign_key :promoted_alerts, :users

    first_id = select_value("SELECT COALESCE(MAX(id), 0) FROM theft_alerts") + ID_HEADROOM
    execute("ALTER SEQUENCE promoted_alerts_id_seq MINVALUE #{first_id} START #{first_id} RESTART")
  end

  def down
    drop_table :promoted_alerts
  end
end
