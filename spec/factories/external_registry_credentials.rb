# == Schema Information
#
# Table name: external_registry_credentials
#
#  id                      :integer          not null, primary key
#  access_token            :string
#  access_token_expires_at :datetime
#  info_hash               :jsonb
#  refresh_token           :string
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  app_id                  :string
#
# Indexes
#
#  index_external_registry_credentials_on_type  (type)
#
FactoryBot.define do
  factory :external_registry_credential do
    factory :project529_credential,
      class: "ExternalRegistryCredential::Project529Credential" do
      access_token { "test" }
      access_token_expires_at { Time.current + 2.days }
      app_id { "test" }
      refresh_token { "test" }
      type { "ExternalRegistryCredential::Project529Credential" }
    end

    factory :stop_heling_credential,
      class: "ExternalRegistryCredential::StopHelingCredential" do
      access_token { "test" }
      access_token_expires_at { nil }
      app_id { "123" }
      refresh_token { nil }
      type { "ExternalRegistryCredential::StopHelingCredential" }
    end
  end
end
