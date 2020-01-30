class AddFeatureSlugsToPaidFeatures < ActiveRecord::Migration[4.2]
  def change
    remove_column :paid_features, :is_locked, :boolean
    add_column :paid_features, :feature_slugs, :text, array: true, default: []
  end
end
