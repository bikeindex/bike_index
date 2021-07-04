class AddStripeKindToPayments < ActiveRecord::Migration[5.2]
  def change
    add_column :payments, :stripe_kind, :integer
  end
end
