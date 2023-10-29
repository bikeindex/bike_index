class CreateLoggedSearches < ActiveRecord::Migration[6.1]
  def change
    create_table :logged_searches do |t|
      t.datetime :request_at
      t.uuid :request_id
      t.text :log_line

      t.integer :endpoint
      t.integer :stolenness
      t.boolean :serial, default: false
      t.boolean :includes_query, default: false
      t.integer :page

      t.integer :duration_ms

      t.jsonb :query_items
      t.string :ip_address

      t.float :latitude
      t.float :longitude

      t.references :organization
      t.references :user

      t.timestamps
    end
    add_index :logged_searches, :request_id
  end
end
