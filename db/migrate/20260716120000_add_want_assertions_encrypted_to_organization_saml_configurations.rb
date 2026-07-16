class AddWantAssertionsEncryptedToOrganizationSamlConfigurations < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_saml_configurations, :want_assertions_encrypted, :boolean, default: false, null: false
  end
end
