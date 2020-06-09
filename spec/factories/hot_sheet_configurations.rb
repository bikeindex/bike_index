FactoryBot.define do
  factory :hot_sheet_configuration do
    organization { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
  end
end
