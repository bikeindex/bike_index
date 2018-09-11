class SwitchPaidFeatureIdsToJsonAndAddNestedOrganizationIds < ActiveRecord::Migration
  def change
    remove_column :organizations, :paid_feature_slugs, :text
    add_column :organizations, :paid_feature_slugs, :jsonb # because equality operator for distinct queries https://github.com/rails/rails/issues/17706
    add_reference :organizations, :parent_organization, index: true
  end
end
