class CreateBikeFlightsRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :bike_flights_requests do |t|
      t.integer :kind, null: false
      t.string :path
      t.jsonb :request_body
      # nil when the request never got a response - a timeout or refused connection
      t.integer :response_status
      t.jsonb :response_body
      t.string :error_message
      t.integer :duration_ms

      t.timestamps
    end
  end
end
