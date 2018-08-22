class CreateInvoices < ActiveRecord::Migration
  def change
    create_table :invoices do |t|
      t.references :organization, index: true
      t.references :subscription_first_invoice_id, index: true
      t.datetime :subscription_start_at
      t.datetime :subscription_end_at
      t.integer :features_at_start_cents
      t.integer :amount_due_cents

      t.timestamps null: false
    end
  end
end