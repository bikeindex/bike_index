class AddIsPaymentToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :is_payment, :boolean, default: false, null: false
  end
end
