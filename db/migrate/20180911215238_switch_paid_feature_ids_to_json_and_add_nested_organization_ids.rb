class SwitchPaidFeatureIdsToJsonAndAddNestedOrganizationIds < ActiveRecord::Migration
  def change
    remove_column :organizations, :paid_feature_slugs, :text
    add_column :organizations, :paid_feature_slugs, :json
    add_reference :organizations, :parent_organization, index: true
  end
end
