class CreateShopifyIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :shopify_integrations do |t|
      t.references :organization, null: false, foreign_key: false, index: false
      t.references :user, null: false, foreign_key: false, index: false
      t.string :shop_domain, null: false
      t.text :access_token, null: false
      t.string :scopes
      t.integer :status, default: 0, null: false
      t.jsonb :shop_data
      t.datetime :webhooks_registered_at
      t.datetime :last_order_at
      t.string :last_error
      t.datetime :last_error_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :shopify_integrations, :organization_id
    add_index :shopify_integrations, :shop_domain, unique: true, where: "deleted_at IS NULL"
  end
end
