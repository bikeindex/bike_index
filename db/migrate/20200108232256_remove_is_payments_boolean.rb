class RemoveIsPaymentsBoolean < ActiveRecord::Migration
  def change
    remove_column :payments, :is_payment, :boolean
  end
end
