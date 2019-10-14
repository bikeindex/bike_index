class CreateExternalRegistryCredentials < ActiveRecord::Migration
  def change
    create_table :external_registry_credentials do |t|
      t.string :type, null: false, index: true
      t.string :app_id
      t.string :access_token
      t.datetime :access_token_expires_at
      t.string :refresh_token
      t.jsonb :info_hash, default: {}

      t.timestamps null: false
    end
  end
end
