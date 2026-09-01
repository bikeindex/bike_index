class RenameEnabledToActiveOnOrganizationSamlConfigurations < ActiveRecord::Migration[8.1]
  def change
    rename_column :organization_saml_configurations, :enabled, :active
  end
end
