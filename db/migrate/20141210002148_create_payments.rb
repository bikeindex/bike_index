class CreatePayments < ActiveRecord::Migration
  def change
    create_table :payments do |t|
      t.integer :user_id
      t.boolean :is_current, default: true, null: true
      t.boolean :is_recurring, default: false, null: false
      t.string :stripe_id
      t.timestamp :last_payment_date
      t.timestamp :first_payment_date
      t.integer :amount

      t.timestamps
    end
    add_index :payments, :user_id
  end
end
