class RenamePaidFeaturesToOrganizationFeatures < ActiveRecord::Migration[5.2]
  def change
    rename_table :paid_features, :organization_features
    rename_table :invoice_paid_features, :invoice_organization_features
    rename_column :invoice_organization_features, :paid_feature_id, :organization_feature_id
  end
end
