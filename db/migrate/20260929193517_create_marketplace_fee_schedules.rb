class CreateMarketplaceFeeSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :marketplace_fee_schedules do |t|
      t.decimal :platform_fee_percent, precision: 5, scale: 2, null: false
      t.integer :platform_fee_cap_cents, null: false
      t.decimal :processing_fee_percent, precision: 5, scale: 2, null: false
      t.datetime :start_at, null: false

      t.timestamps
    end
  end
end
