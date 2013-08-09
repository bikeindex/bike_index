class RemoveLingeringInvoiceAttributes < ActiveRecord::Migration
  def up
    remove_column :bikes, :invoice_id
    remove_column :organizations, :paid
  end

  def down
    add_column :bikes, :invoice_id, :integer
    add_column :organizations, :paid, :boolean
  end
end
