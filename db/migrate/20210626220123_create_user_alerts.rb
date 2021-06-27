class CreateUserAlerts < ActiveRecord::Migration[5.2]
  def change
    rename_column :users, :general_alerts, :alert_slugs

    create_table :user_alerts do |t|
      t.references :user, index: true
      t.references :user_phone, index: true
      t.references :bike, index: true
      t.references :organization

      t.text :message
      t.integer :kind
      t.datetime :resolved_at
      t.datetime :dismissed_at

      t.timestamps
    end
  end
end
