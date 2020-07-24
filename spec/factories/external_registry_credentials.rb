FactoryBot.define do
  factory :external_registry_credentials do
    factory :project529_credentials,
      class: "ExternalRegistryCredential::Project529Credential" do
      access_token { "test" }
      access_token_expires_at { Time.current + 2.days }
      app_id { "test" }
      refresh_token { "test" }
      type { "ExternalRegistryCredential::Project529Credential" }
    end

    factory :stop_heling_credentials,
      class: "ExternalRegistryCredential::StopHelingCredential" do
      access_token { "test" }
      access_token_expires_at { nil }
      app_id { "123" }
      refresh_token { nil }
      type { "ExternalRegistryCredential::StopHelingCredential" }
    end
  end
end
