FactoryBot.define do
  factory :impound_configuration do
    organization { FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs: "impound_bikes") }
  end
end
