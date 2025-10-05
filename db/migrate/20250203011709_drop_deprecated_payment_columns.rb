class DropDeprecatedPaymentColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :payments, :is_current, :boolean, default: true
    remove_column :payments, :is_recurring, :boolean, default: false
    remove_column :payments, :stripe_kind, :integer
    remove_column :payments, :last_payment_date, :datetime
    rename_column :payments, :first_payment_date, :paid_at
  end
end
