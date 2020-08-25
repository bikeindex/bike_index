class AddEndlessToInvoices < ActiveRecord::Migration[5.2]
  def change
    add_column :invoices, :is_endless, :boolean, default: false
  end
end
