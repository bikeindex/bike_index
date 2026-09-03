class DropIntegrations < ActiveRecord::Migration[8.1]
  def up
    drop_table :integrations
  end

  def down
    create_table :integrations do |t|
      t.integer :user_id
      t.text :access_token
      t.string :provider_name
      t.text :information
      t.timestamps null: false
    end
    add_index :integrations, :user_id
  end
end
