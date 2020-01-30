class RemoveIsPaymentsBoolean < ActiveRecord::Migration[4.2]
  def change
    remove_column :payments, :is_payment, :boolean
  end
end
