FactoryBot.define do
  factory :organization_saml_configuration do
    # Sequenced because two saml_sso organizations may not claim the same domain
    sequence(:organization) do |n|
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: "saml_sso", user_email_domain: "sso-#{n}.example.com")
    end

    trait :active do
      active { true }
      idp_entity_id { "https://idp.example.edu/" }
      idp_sso_target_url { "https://idp.example.edu/idp/profile/SAML2/POST/SSO" }
      idp_cert { File.read(Rails.root.join("spec/fixtures/saml/idp_cert.pem")) }
    end
  end
end
