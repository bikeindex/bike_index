class AddTheftAlerts < ActiveRecord::Migration[4.2]
  def change
    create_table :theft_alerts do |t|
      t.belongs_to :stolen_record, index: true
      t.foreign_key :stolen_records, on_delete: :cascade

      t.belongs_to :theft_alert_plan, index: true
      t.foreign_key :theft_alert_plans, on_delete: :cascade

      t.belongs_to :payment, index: true
      t.foreign_key :payments

      t.belongs_to :user, index: true
      t.foreign_key :users

      t.integer :status, null: false, default: 0

      t.string :facebook_post_url, null: false, default: ""
      t.datetime :begin_at
      t.datetime :end_at

      t.timestamps null: false
    end
  end
end
