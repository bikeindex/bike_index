class CreatePromotedAlerts < ActiveRecord::Migration[8.1]
  def up
    # The foreign keys below lock out writes to the tables they reference. Fail rather than
    # queue behind a long transaction and take those writes down with us
    execute("SET LOCAL lock_timeout = '5s'")

    # The follow-up backfill copies theft_alerts across keeping their ids. Reserve room above
    # them, so an alert created before it runs can't take an id the copy still needs - it would
    # be skipped, and its notifications would end up on whichever alert did take the id
    first_id = select_value("SELECT COALESCE(MAX(id), 0) FROM theft_alerts") + 10_000

    create_table :promoted_alerts do |t|
      t.references :stolen_record, type: :integer, foreign_key: {on_delete: :cascade}
      t.references :theft_alert_plan, type: :integer, foreign_key: {on_delete: :cascade}
      t.references :payment, type: :integer, foreign_key: true
      t.references :user, type: :integer, foreign_key: true
      t.integer :status, default: 0, null: false
      t.datetime :start_at
      t.datetime :end_at
      t.timestamps
      t.text :notes
      t.jsonb :facebook_data
      t.float :latitude
      t.float :longitude
      t.integer :reach
      t.bigint :bike_id, index: true
      t.datetime :facebook_updated_at
      t.integer :amount_cents_facebook_spent
      t.boolean :admin, default: false
      t.integer :ad_radius_miles
    end

    # pg_dump writes START into db/structure.sql, so databases built by db:schema:load get the
    # reservation too - a setval wouldn't reach them
    execute("ALTER SEQUENCE promoted_alerts_id_seq START #{first_id} RESTART")
  end

  def down
    drop_table :promoted_alerts
  end
end
