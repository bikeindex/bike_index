FactoryBot.define do
  factory :external_registry_credentials,
          class: "ExternalRegistryCredential::Project529Credential" do
    access_token { "test" }
    access_token_expires_at { Time.current + 2.days }
    app_id { "test" }
    refresh_token { "test" }
    type { "ExternalRegistryCredential::Project529Credential" }
  end
end
