class AddAllowIdpInitiatedToOrganizationSamlConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_saml_configurations, :allow_idp_initiated, :boolean, default: false
  end
end
