FactoryBot.define do
  factory :organization_saml_configuration do
    organization { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso") }

    trait :enabled do
      enabled { true }
      idp_entity_id { "https://idp.example.edu/" }
      idp_sso_target_url { "https://idp.example.edu/idp/profile/SAML2/POST/SSO" }
      idp_cert { File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")) }
    end
  end
end
