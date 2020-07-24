class AddCurrencyToPayment < ActiveRecord::Migration[4.2]
  def change
    add_column :payments,
      :currency,
      :string,
      null: false,
      default: "USD"
  end
end
