class AddChildPaidFeaturesToInvoices < ActiveRecord::Migration[4.2]
  def change
    add_column :invoices, :child_paid_feature_slugs, :jsonb
  end
end
