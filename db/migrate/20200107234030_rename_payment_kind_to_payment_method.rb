class RenamePaymentKindToPaymentMethod < ActiveRecord::Migration
  def change
    rename_column :payments, :kind, :payment_method
  end
end
