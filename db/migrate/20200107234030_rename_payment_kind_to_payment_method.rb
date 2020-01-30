class RenamePaymentKindToPaymentMethod < ActiveRecord::Migration[4.2]
  def change
    rename_column :payments, :kind, :payment_method
    add_column :payments, :kind, :integer
  end
end
