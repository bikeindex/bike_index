class AddChildPaidFeaturesToInvoices < ActiveRecord::Migration
  def change
    add_column :invoices, :child_paid_feature_slugs, :jsonb
  end
end
