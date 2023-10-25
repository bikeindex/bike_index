class CreateLoggedSearches < ActiveRecord::Migration[6.1]
  def change
    create_table :logged_searches do |t|
      t.datetime :request_at
      t.string :request_id
      t.text :log_line

      t.integer :endpoint
      t.integer :stolenness
      t.boolean :serial, default: false

      t.integer :duration

      t.jsonb :search_query
      t.string :ip_address

      t.float :latitude
      t.float :latitude

      t.references :organization
      t.references :user

      t.timestamps
    end
  end
end
