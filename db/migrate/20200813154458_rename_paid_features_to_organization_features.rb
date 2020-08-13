class RenamePaidFeaturesToOrganizationFeatures < ActiveRecord::Migration[5.2]
  def change
    rename_table :paid_features, :organization_features
  end
end
