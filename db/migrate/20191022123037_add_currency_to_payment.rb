class AddCurrencyToPayment < ActiveRecord::Migration
  def change
    add_column :payments,
               :currency,
               :string,
               null: false,
               default: "USD"
  end
end
