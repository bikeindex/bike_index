class AddStripeStatusToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :stripe_status, :string
  end
end
