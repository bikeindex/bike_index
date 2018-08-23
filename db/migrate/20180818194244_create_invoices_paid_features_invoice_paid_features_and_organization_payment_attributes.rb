# Doing all these together because they are all intermingled, and attributes are connected
# Having one file makes it easier to track
class CreateInvoicesPaidFeaturesInvoicePaidFeaturesAndOrganizationPaymentAttributes < ActiveRecord::Migration
  def change
    create_table :invoices do |t|
      t.references :organization, index: true
      t.references :first_invoice, index: true
      t.boolean :is_active, default: false, null: false
      t.boolean :force_active, default: false, null: false
      t.datetime :subscription_start_at
      t.datetime :subscription_end_at
      t.integer :amount_due_cents
      t.integer :amount_paid_cents

      t.timestamps null: false
    end

    create_table :paid_features do |t|
      t.integer :kind, default: 0
      t.integer :amount_cents
      t.string :name
      t.string :slug
      t.boolean :is_locked, default: false, null: false
      t.text :description
      t.string :details_link

      t.timestamps null: false
    end

    create_table :invoice_paid_features do |t|
      t.references :invoice, index: true
      t.references :paid_feature, index: true

      t.timestamps null: false
    end

    rename_column :payments, :amount, :amount_cents
    add_column :payments, :kind, :integer, default: 0
    add_reference :payments, :organization
    add_reference :payments, :invoice
    add_column :organizations, :paid_feature_slugs, :text, array: true, default: []
  end
end
