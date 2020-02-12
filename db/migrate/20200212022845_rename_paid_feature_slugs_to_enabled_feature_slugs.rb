class RenamePaidFeatureSlugsToEnabledFeatureSlugs < ActiveRecord::Migration[5.2]
  def change
    rename_column :organizations, :paid_feature_slugs, :enabled_feature_slugs
    rename_column :invoices, :child_paid_feature_slugs, :child_enabled_feature_slugs
  end
end
