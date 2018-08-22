# Doing all these together because they are all intermingled, and attributes are connected
# Having one file makes it easier to track
class CreateInvoicesPaidFeaturesInvoicePaidFeaturesAndOrganizationPaymentAttributes < ActiveRecord::Migration
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

    create_table :paid_features do |t|
      t.integer :kind, default: 0
      t.string :name
      t.string :slug
      t.boolean :name_locked
      t.text :descrtiption
      t.integer :upfront_cents
      t.integer :recurring_cents

      t.timestamps null: false
    end

    create_table :invoice_paid_features do |t|
      t.references :invoice, index: true
      t.references :paid_feature, index: true

      t.timestamps null: false
    end

    add_column :payments, :kind, :integer, default: 0
    add_reference :payments, :organization
    add_reference :payments, :invoice
    add_column :organizations, :paid_feature_slugs, :text, array: true, default: []
  end
end
