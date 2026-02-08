class CreateStravaRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :strava_requests do |t|
      t.references :user
      t.bigint :strava_integration_id, null: false
      t.integer :request_type, null: false
      t.string :endpoint, null: false
      t.jsonb :parameters, default: {}
      t.datetime :requested_at
      t.integer :response_status, default: 0, null: false

      t.timestamps
    end
    add_index :strava_requests, [:strava_integration_id, :requested_at]
  end
end
