class CreateOrganizationSamlConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_saml_configurations do |t|
      t.references :organization, index: {unique: true}
      t.boolean :enabled, default: false
      t.string :idp_entity_id
      t.string :idp_sso_target_url
      t.string :idp_slo_target_url
      t.text :idp_cert
      t.string :idp_cert_fingerprint
      t.text :idp_cert_multi
      t.string :email_attribute_name
      t.string :name_id_format

      t.timestamps
    end
  end
end
